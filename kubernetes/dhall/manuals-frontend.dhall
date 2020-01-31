let shared = ./shared.dhall

in  shared.basicBuilder "manuals-frontend" "/healthcheck" 3000
