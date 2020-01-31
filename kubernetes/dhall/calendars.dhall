let shared = ./shared.dhall

in  shared.basicBuilder "calendars" "/bank-holidays" 3000
