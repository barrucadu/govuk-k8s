let shared = ./shared.dhall

in  shared.basicBuilder "info-frontend" "/healthcheck" 3000
