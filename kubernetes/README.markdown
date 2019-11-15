Kubernetes
==========

Pre-requisites:

- Run the provisioning scripts

Scripts:

- `./deploy.sh` - deploy a namespace.


Namespace: live
---------------

Runs a subset of the frontend apps against the live GOV.UK APIs.  This
is effectively the same as what you get [running `./startup.sh --live`
in frontend app repositories][], but the app is run in production mode
rather than development mode.

The following apps are working in the live environment:

- [calculators][]
- [calendars][]
- [collections][]
- [finder-frontend][]
- [frontend][]
- [government-frontend][]
- [info-frontend][]
- [manuals-frontend][]
- [service-manual-frontend][]
- [smart-answers][]

Apps are available at `APP-NAME.live.web.EXTERNAL-DOMAIN-NAME`.  As
the apps are not running in development mode, some of them won't have
a page at `/`.

[running `./startup.sh --live` in frontend app repositories]: https://github.com/alphagov/finder-frontend/blob/master/startup.sh


Namespace: govuk
----------------

TODO


Secrets
-------

To avoid the need to duplicate app definitions with small tweaks
between environments, Kubernetes secrets are used to store
environment-specific configuration.  The secret is called `govuk` and
in general looks like this:

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: govuk
stringData:
  GOVUK_APP_DOMAIN: "..."
  GOVUK_ASSET_ROOT: "..."
  GOVUK_WEBSITE_ROOT: "..."
  PLEK_SERVICE_CONTENT_STORE_URI: "..."
  PLEK_SERVICE_SEARCH_URI: "..."
  PLEK_SERVICE_STATIC_URI: "..."
  PLEK_SERVICE_WHITEHALL_ADMIN_URI: "..."
  K8S_HOSTNAMES-calculators: "..."
  K8S_HOSTNAMES-calendars: "..."
  K8S_HOSTNAMES-collections: "..."
  K8S_HOSTNAMES-finder-frontend: "..."
  K8S_HOSTNAMES-frontend: "..."
  K8S_HOSTNAMES-government-frontend: "..."
  K8S_HOSTNAMES-info-frontend: "..."
  K8S_HOSTNAMES-manuals-frontend: "..."
  K8S_HOSTNAMES-service-manual-frontend: "..."
  K8S_HOSTNAMES-smart-answers: "..."
  SECRET_KEY_BASE-calculators: TPL_UUID
  SECRET_KEY_BASE-calendars: TPL_UUID
  SECRET_KEY_BASE-collections: TPL_UUID
  SECRET_KEY_BASE-finder-frontend: TPL_UUID
  SECRET_KEY_BASE-frontend: TPL_UUID
  SECRET_KEY_BASE-government-frontend: TPL_UUID
  SECRET_KEY_BASE-info-frontend: TPL_UUID
  SECRET_KEY_BASE-manuals-frontend: TPL_UUID
  SECRET_KEY_BASE-service-manual-frontend: TPL_UUID
  SECRET_KEY_BASE-smart-answers: TPL_UUID
```

See `live/secrets.yaml.template` and `govuk/secrets.yaml.template` to
see the concrete values for the `"..."` placeholders.

There are two template variables expanded by `deploy.sh` to produce
the final `secrets.yaml`:

- `TPL_EXTERNAL_DOMAIN_NAME`: set to the `EXTERNAL_DOMAIN_NAME` in `../config`
- `TPL_UUID`: set to a random uuid, with each `TPL_UUID` different


[calculators]: https://github.com/alphagov/calculators
[calendars]: https://github.com/alphagov/calendars
[collections]: https://github.com/alphagov/collections
[finder-frontend]: https://github.com/alphagov/finder-frontend
[frontend]: https://github.com/alphagov/frontend
[government-frontend]: https://github.com/alphagov/government-frontend
[info-frontend]: https://github.com/alphagov/info-frontend
[manuals-frontend]: https://github.com/alphagov/manuals-frontend
[service-manual-frontend]: https://github.com/alphagov/service-manual-frontend
[smart-answers]: https://github.com/alphagov/smart-answers
