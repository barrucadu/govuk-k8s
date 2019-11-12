Continuous Integration
======================

Pre-requisites:

- Check that `ci.<external domain>` resolves and that you can log in
- Install the `fly` tool (available for download from `ci.<external domain>`)

Scripts:

- `./create.sh` - run `deploy-ci.sh` and `build-all-apps.sh` scripts
- `./deploy-ci.sh` - deploy pipelines to Concourse
- `./build-all-apps.sh` - trigger a build all apps


Pipelines
---------

There is currently only one pipeline, which performs continuous
integration.  In the future there will be continuous deployment.

### CI

Builds docker images for GOV.UK apps and pushes them to
`registry.govuk-k8s.test` when:

- The `govuk-base` image is updated
- The `deployed-to-production` branch of the app's git repository is pushed to

The `govuk-base` image is never built automatically, builds must be
triggered through the Concourse UI or the `build-all-apps.sh` script.

This pipeline only builds docker images for a subset of GOV.UK apps at
the moment.
