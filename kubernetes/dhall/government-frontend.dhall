let shared = ./shared.dhall

in  shared.basicBuilder "government-frontend" "/healthcheck" 3000
