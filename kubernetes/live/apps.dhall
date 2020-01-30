let shared = ../dhall/shared.dhall

let namespace = { name = "live" }

let env
    : Text → shared.GovukEnv.Type
    =   λ(app_name : Text)
      → { vars =
          [ { key = "GOVUK_APP_DOMAIN", value = "www.gov.uk" }
          , { key = "GOVUK_ASSET_ROOT", value = "" }
          , { key = "GOVUK_WEBSITE_ROOT", value = "https://www.gov.uk" }
          , { key = "PLEK_SERVICE_CONTENT_STORE_URI"
            , value = "https://www.gov.uk/api"
            }
          , { key = "PLEK_SERVICE_SEARCH_URI"
            , value = "https://www.gov.uk/api"
            }
          , { key = "PLEK_SERVICE_STATIC_URI"
            , value = "assets.publishing.service.gov.uk"
            }
          , { key = "PLEK_SERVICE_WHITEHALL_ADMIN_URI"
            , value = "https://www.gov.uk"
            }
          , { key = "HOST", value = "0.0.0.0" }
          , { key = "RAILS_ENV", value = "production" }
          , { key = "RAILS_SERVE_STATIC_FILES", value = "true" }
          , { key = "K8S_HOSTNAMES"
            , value = shared.k8sHostname namespace app_name
            }
          ]
        , secrets =
          [ { key = "SECRET_KEY_BASE", value = "SECRET_KEY_BASE-" ++ app_name }
          ]
        }

in    λ(enableHTTPS : Bool)
    → λ(externalDomainName : Text)
    → shared.mergeConfig
        [ ../dhall/fake-router.dhall namespace enableHTTPS externalDomainName 2
        , ../dhall/calculators.dhall namespace (env "calculators") 2
        , ../dhall/calendars.dhall namespace (env "calendars") 2
        , ../dhall/collections.dhall namespace (env "collections") 2
        , ../dhall/finder-frontend.dhall namespace (env "finder-frontend") 2
        , ../dhall/frontend.dhall namespace (env "frontend") 2
        , ../dhall/government-frontend.dhall
            namespace
            (env "government-frontend")
            2
        , ../dhall/info-frontend.dhall namespace (env "info-frontend") 2
        , ../dhall/manuals-frontend.dhall namespace (env "manuals-frontend") 2
        , ../dhall/service-manual-frontend.dhall
            namespace
            (env "service-manual-frontend")
            2
        , ../dhall/smart-answers.dhall namespace (env "smart-answers") 2
        ]
