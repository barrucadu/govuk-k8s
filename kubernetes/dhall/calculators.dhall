let shared = ./shared.dhall

in  shared.basicBuilder "calculators" "/child-benefit-tax-calculator/main" 3000
