let prelude =
      https://raw.githubusercontent.com/dhall-lang/dhall-kubernetes/master/1.14/Prelude.dhall sha256:771c7131fc87e13eb18f770a27c59f9418879f7e230ba2a50e46f4461f43ec69

let kubernetes =
      https://raw.githubusercontent.com/dhall-lang/dhall-kubernetes/master/1.14/package.dhall sha256:464526c76afadd12c0aca27ee314559794203517f1d9bf20a4925ba50977af58

let wrap =
      https://raw.githubusercontent.com/dhall-lang/dhall-kubernetes/master/1.14/typesUnion.dhall sha256:b1de6f5c7b4ec1cb9e7d15c977117e6e57365e104afe01249deca36de935d919

let kv = prelude.JSON.keyText

let GovukNamespace = { Type = { name : Text } }

let GovukKV = { Type = { key : Text, value : Text } }

let GovukEnv =
      { Type = { vars : List GovukKV.Type, secrets : List GovukKV.Type }
      , default =
          { vars = [] : List GovukKV.Type, secrets = [] : List GovukKV.Type }
      }

let GovukApp =
      { Type =
          { name : Text
          , replicas : Natural
          , port : Natural
          , env : GovukEnv.Type
          }
      }

let GovukIngress =
      { Type = { healthcheck_path : Text, healthcheck_codes : Text }
      , default = { healthcheck_path = "/", healthcheck_codes = "200" }
      }

let GovukAppKubernetesConfig =
      { Type = { apiVersion : Text, kind : Text, items : List wrap } }

let k8sHostname
    : GovukNamespace.Type → Text → Text
    =   λ(namespace : GovukNamespace.Type)
      → λ(app_name : Text)
      → app_name ++ "." ++ namespace.name ++ ".in-cluster.govuk-k8s.test"

let makeDeployment
    : GovukNamespace.Type → GovukApp.Type → kubernetes.Deployment.Type
    =   λ(namespace : GovukNamespace.Type)
      → λ(app : GovukApp.Type)
      → let env_vars =
              prelude.List.map
                GovukKV.Type
                kubernetes.EnvVar.Type
                (   λ(e : GovukKV.Type)
                  → kubernetes.EnvVar::{ name = e.key, value = Some e.value }
                )
                app.env.vars

        let secrets =
              prelude.List.map
                GovukKV.Type
                kubernetes.EnvVar.Type
                (   λ(e : GovukKV.Type)
                  → kubernetes.EnvVar::{
                    , name = e.key
                    , valueFrom = Some kubernetes.EnvVarSource::{
                      , secretKeyRef = Some kubernetes.SecretKeySelector::{
                        , name = Some "govuk"
                        , key = e.value
                        , optional = Some False
                        }
                      }
                    }
                )
                app.env.secrets

        in  kubernetes.Deployment::{
            , metadata = kubernetes.ObjectMeta::{ name = app.name }
            , spec = Some kubernetes.DeploymentSpec::{
              , replicas = Some app.replicas
              , selector = kubernetes.LabelSelector::{
                , matchLabels = Some [ kv "run" app.name ]
                }
              , template = kubernetes.PodTemplateSpec::{
                , metadata = kubernetes.ObjectMeta::{
                  , name = app.name
                  , labels = Some [ kv "run" app.name ]
                  }
                , spec = Some kubernetes.PodSpec::{
                  , containers =
                    [ kubernetes.Container::{
                      , name = app.name
                      , image = Some
                          ("registry.govuk-k8s.test:5000/" ++ app.name)
                      , imagePullPolicy = Some "Always"
                      , ports = Some
                          [ kubernetes.ContainerPort::{
                            , containerPort = app.port
                            }
                          ]
                      , env = Some (env_vars # secrets)
                      }
                    ]
                  }
                }
              }
            }

let makeService
    : GovukNamespace.Type → GovukApp.Type → kubernetes.Service.Type
    =   λ(namespace : GovukNamespace.Type)
      → λ(app : GovukApp.Type)
      → kubernetes.Service::{
        , metadata = kubernetes.ObjectMeta::{
          , name = app.name
          , namespace = Some namespace.name
          }
        , spec = Some kubernetes.ServiceSpec::{
          , selector = Some [ kv "run" app.name ]
          , type = Some "NodePort"
          , ports = Some
              [ kubernetes.ServicePort::{
                , targetPort = Some (kubernetes.IntOrString.Int app.port)
                , port = 3000
                }
              ]
          }
        }

let makeIngress
    :   GovukNamespace.Type
      → GovukApp.Type
      → GovukIngress.Type
      → kubernetes.Ingress.Type
    =   λ(namespace : GovukNamespace.Type)
      → λ(app : GovukApp.Type)
      → λ(ingress : GovukIngress.Type)
      → kubernetes.Ingress::{
        , metadata = kubernetes.ObjectMeta::{
          , name = app.name
          , namespace = Some namespace.name
          , annotations = Some
              [ kv "kubernetes.io/ingress.class" "alb"
              , kv "alb.ingress.kubernetes.io/scheme" "internal"
              , kv
                  "alb.ingress.kubernetes.io/tags"
                  ("App=" ++ app.name ++ ",Namespace=" ++ namespace.name)
              , kv
                  "alb.ingress.kubernetes.io/healthcheck-path"
                  ingress.healthcheck_path
              , kv
                  "alb.ingress.kubernetes.io/healthcheck-codes"
                  ingress.healthcheck_codes
              ]
          }
        , spec = Some kubernetes.IngressSpec::{
          , rules = Some
              [ kubernetes.IngressRule::{
                , host = Some (k8sHostname namespace app.name)
                , http = Some
                    { paths =
                      [ { path = Some "/*"
                        , backend =
                            { serviceName = app.name
                            , servicePort = kubernetes.IntOrString.Int 3000
                            }
                        }
                      ]
                    }
                }
              ]
          }
        }

let makeApp
    :   GovukNamespace.Type
      → GovukApp.Type
      → GovukIngress.Type
      → GovukAppKubernetesConfig.Type
    =   λ(namespace : GovukNamespace.Type)
      → λ(app : GovukApp.Type)
      → λ(ingress : GovukIngress.Type)
      → { apiVersion = "v1"
        , kind = "List"
        , items =
          [ wrap.Deployment (makeDeployment namespace app)
          , wrap.Service (makeService namespace app)
          , wrap.Ingress (makeIngress namespace app ingress)
          ]
        }

let mergeConfig
    : List GovukAppKubernetesConfig.Type → GovukAppKubernetesConfig.Type
    =   λ(configs : List GovukAppKubernetesConfig.Type)
      → { apiVersion = "v1"
        , kind = "List"
        , items =
            prelude.List.concatMap
              GovukAppKubernetesConfig.Type
              wrap
              (λ(config : GovukAppKubernetesConfig.Type) → config.items)
              configs
        }

let basicBuilder
    :   Text
      → Text
      → Natural
      → GovukNamespace.Type
      → GovukEnv.Type
      → Natural
      → GovukAppKubernetesConfig.Type
    =   λ(app_name : Text)
      → λ(healthcheck_path : Text)
      → λ(port : Natural)
      → λ(namespace : GovukNamespace.Type)
      → λ(env : GovukEnv.Type)
      → λ(replicas : Natural)
      → makeApp
          namespace
          { name = app_name, replicas = replicas, port = port, env = env }
          GovukIngress::{ healthcheck_path = healthcheck_path }

in  { GovukNamespace = GovukNamespace
    , GovukKV = GovukKV
    , GovukEnv = GovukEnv
    , GovukApp = GovukApp
    , GovukIngress = GovukIngress
    , GovukAppKubernetesConfig = GovukAppKubernetesConfig
    , makeDeployment = makeDeployment
    , makeService = makeService
    , makeIngress = makeIngress
    , makeApp = makeApp
    , mergeConfig = mergeConfig
    , k8sHostname = k8sHostname
    , basicBuilder = basicBuilder
    }
