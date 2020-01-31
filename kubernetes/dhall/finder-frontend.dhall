let shared = ./shared.dhall

in  shared.basicBuilder "finder-frontend" "/search" 3000
