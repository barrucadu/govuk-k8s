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

TODO

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
