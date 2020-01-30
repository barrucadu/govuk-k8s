let shared = ./shared.dhall

in  shared.basicBuilder "service-manual-frontend" "/healthcheck" 3000
