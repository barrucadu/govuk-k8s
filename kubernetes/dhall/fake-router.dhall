let shared = ./shared.dhall

let builder
    :   shared.GovukNamespace.Type
      → Bool
      → Text
      → Natural
      → shared.GovukAppKubernetesConfig.Type
    =   λ(namespace : shared.GovukNamespace.Type)
      → λ(enableHTTPS : Bool)
      → λ(externalDomainName : Text)
      → λ(replicas : Natural)
      → shared.makeApp
          namespace
          { name = "fake-router"
          , replicas = replicas
          , port = 3000
          , env = shared.GovukEnv::{
            , vars =
              [ { key = "PLEK_SERVICE_CONTENT_STORE_URI"
                , value = "https://www.gov.uk/api"
                }
              , { key = "FAKE_ROUTER_HTTPS"
                , value = if enableHTTPS then "true" else "false"
                }
              , { key = "FAKE_ROUTER_DOMAIN"
                , value = namespace.name ++ ".web." ++ externalDomainName
                }
              ]
            }
          }
          shared.GovukIngress::{ healthcheck_codes = "302" }

in  builder
