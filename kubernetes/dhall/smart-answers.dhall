let shared = ./shared.dhall

in  shared.basicBuilder "smart-answers" "/healthcheck" 3000
