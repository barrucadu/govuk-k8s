# Decision record: Use EKS, rather than self-managing

**Date:** 2019-11-16

1. [The problem with self-managing](#the-problem-with-self-managing)
2. [kops vs EKS](#kops-vs-eks)
3. [Consequences of switching to EKS](#consequences-of-switching-to-eks)
   1. [Availability](#availability)
   1. [Cost](#cost)
   2. [Ingress](#ingress)
   3. [Scaling](#scaling)


## The problem with self-managing

NixOS provides a high-level abstraction over provisioning Kubernetes
clusters:

```nix
# a master instance
services.kubernetes.roles = ["master"];

# or a worker instance
services.kubernetes.roles = ["node"];
```

Making a machine a "node" generates a script for you which you can run
to have it communicate with the master and join the cluster, as long
as you copy across a secret key which the master generates.  TLS
certificates are managed automatically, by the master acting as a
certificate authority.  Multi-node networking is configured for you.

In short, it seems to do everything you might want, and requires very
little knowledge of the low-level details of managing a Kubernetes
cluster.

Unfortunately the reality is not quite there:

- I spent a day or so trying to figure out why the generated TLS certs
  were missing hostnames, and making the worker/master communication
  fail.  It turns out that it's because the NixOS AWS AMI doesn't set
  `networking.hostName`, it sets the hostname on boot from the EC2
  metadata service---but the Kubernetes configuration uses
  `networking.hostName` ([nixpkgs#73139](https://github.com/NixOS/nixpkgs/pull/73139)).

- The bootstrapping process is complicated and fragile
  ([nixpkgs#61135](https://github.com/NixOS/nixpkgs/issues/61135)).
  Sometimes my cluster would boot up and everything would work.
  Sometimes it would boot up and cross-node networking wouldn't work.
  Packets arrived at the target machine, but were then dropped.
  Because this is random, and seems to happen immediately at cluster
  startup, I assume it's a race condition in setting up the networking
  stack somewhere.  I couldn't figure it out.

So, having spent a week and a half trying to chase down this
networking issue, I gave up.  I started govuk-k8s to learn how to use
Kubernetes, not to stare at `tcpdump` and `iptables` output.


## kops vs EKS

So, what are the alternatives?

The main one seems to be [kops][] (Kubernetes Operations).  It looks
like kops relies a lot on using the `kops` command-line tool to
configure stuff, and then for the user to export the corresponding
yaml (or terraform).

This sounds good for interactive use, but less good for something that
someone else could, in principle, use.  The generated configuration
has concrete references to things like AWS resource identifiers, it
doesn't look very portable.

Also in general I like having text files be the source of truth, and
not merely be a dump of the internal data structures of some tool.
Editing those text files would bee like defining all your
infrastructure by writing .tfstate JSON files: a huge pain.

The other popular alternative is [EKS][] (Amazon Elastic Kubernetes
Service).  EKS is a partially-managed service: it provides a managed
"control plane" (Kubernetes API server, etc), but not worker
instances.  You have to provision those yourself and connect them to
the cluster.

However, Amazon have a strong financial interest in making it easy to
provision Kubernetes worker instances and connect them to EKS.  To
that end, they provide an AMI for EKS-optimised Kubernetes worker
instances.  With master instances managed by EKS and worker instances
configured by the official AMI, you effectively have a managed
Kubernetes cluster: true, you need to scale workers yourself, and
Amazon won't help you if your workers run out of resources, but they
will make the AMI as easy to use as possible.

EKS more fits how I like to work than kops, and I desperately want to
stop self-managing Kubernetes networking... so I've decided to go with
EKS + the worker AMI.

[kops]: https://github.com/kubernetes/kops
[EKS]: https://aws.amazon.com/eks/


## Consequences of switching to EKS

EKS, similar to other AWS managed services like RDS, has some opinions
on how your infrastructure must be in order for you to use it.

### Availability

EKS cannot be deployed to a single availability zone, it needs at
least two.  Up until now, all of my infrastructure has been in a
single availability zone.  To make this happen I've introduced more
subnets:

| CIDR          | Type    | Availability zone |
| ------------- | ------- | ----------------- |
| `10.0.0.0/24` | Public  | `eu-west-2a`      |
| `10.0.1.0/24` | Private | `eu-west-2a`      |
| `10.0.2.0/24` | Public  | `eu-west-2b`      |
| `10.0.3.0/24` | Private | `eu-west-2b`      |
| `10.0.4.0/24` | Public  | `eu-west-2c`      |
| `10.0.5.0/24` | Private | `eu-west-2c`      |

Each availability zone has a public and a private subnet.  Where
before I had a single NAT gateway, now each private subnet has a NAT
gateway in its corresponding public subnet.

The EKS control plane is deployed across all three private subnets.
The EC2 worker instances are similarly deployed across all three
private subnets.  The other machines (`jumpbox`, `ci`, `registry`,
`web`) are only deployed to the `eu-west-2a` subnets.

So availability hasn't improved yet: ingress is still reliant on a
single EC2 instance.  However, with the cluster now spread across
multiple availability zones, there is only one small and relatively
simple problem remaining before govuk-k8s is highly available.

The NixOS easy Kubernetes setup doesn't work at all for a HA setting,
as the TLS certificate provisioning part doesn't work with multiple
masters.


### Cost

The amount of infrastructure has increased significantly:

- Two more Elastic IPs
- Two more NAT gateways
- An EKS cluster
- Scaling groups, load balancers, and Route53 entries

And all we've got rid of is one EC2 instance (`k8s-master`).

I'm not sure how much more this is going to cost, but let's just say
I'm happy I wrote the shrinking script.

To mitigate matters I've reduced the sizes of all the EC2 instances,
as they didn't need to be as big as they were.


### Ingress

The EKS workers are behind an autoscaling group, so I can't rely on
any one machine existing for me to route traffic to from `web`, which
has forced me to implement proper ingress handling.

There is [an AWS ALB ingress controller][], which manages ALBs
automatically for ingress resources.  The only additional requirement
is that the service exposes a `NodePort` but, unlike my previous
set-up, it doesn't have to be a previously known and agreed-upon port.

Together the service and ingress configuration look like this:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: fake-router
  namespace: live
spec:
  selector:
    run: fake-router
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
  type: NodePort

---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: fake-router
  namespace: live
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/tags: App=fake-router,Namespace=live
    alb.ingress.kubernetes.io/success-codes: "302"
spec:
  rules:
    - host: fake-router.live.in-cluster.govuk-k8s.test
      http:
        paths:
          - path: /*
            backend:
              serviceName: fake-router
              servicePort: 3000
```

With the help of [an automatic AWS Route53 manager][], DNS records in
the internal zone can be created and attached to these load balancers
as they come up.  So here is the workflow now:

1. A `NodePort` service is deployed
2. An ingress resource which connects to that service is deployed
3. An ALB is automatically created and connected to the service's port
4. A Route53 record is automatically created and pointed at the ALB

This is much better than a big list of reserved port numbers.

[an AWS ALB ingress controller]: https://github.com/kubernetes-sigs/aws-alb-ingress-controller/
[an automatic AWS Route53 manager]: https://github.com/kubernetes-sigs/external-dns

### Scaling

Scaling the cluster up and down is much easier now than it was before:

- The EKS cluster is a managed service.
- The EKS worker nodes are not managed, but are configured to join the
  cluster on boot.

So scaling consists of saying "just do it" and waiting.  In the
previous set-up I would need to deploy the NixOS configuration to any
new nodes and then join them to the cluster.
