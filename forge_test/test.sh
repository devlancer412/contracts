# Normal test
forge test --no-match-contract EggSaleTest

# Forking test
# && forge test --fork-url $(grep POLYGON_RPC_URL .env | cut -d '=' -f2) --match-contract EggSaleTest
