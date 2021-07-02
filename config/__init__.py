# Ideally, they have one file with the settings for the strat and deployment
# This file would allow them to configure so they can test, deploy and interact with the strategy

BADGER_DEV_MULTISIG = "0xb65cef03b9b89f99517643226d76e286ee999e77"

# For the Polygon Mainnet
WANT = "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063"  # Dai
REWARD_TOKEN = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"  # WMATIC Token

PROTECTED_TOKENS = [WANT, REWARD_TOKEN]
#  Fees in Basis Points
DEFAULT_GOV_PERFORMANCE_FEE = 1000
DEFAULT_PERFORMANCE_FEE = 1000
DEFAULT_WITHDRAWAL_FEE = 75

FEES = [DEFAULT_GOV_PERFORMANCE_FEE,
        DEFAULT_PERFORMANCE_FEE, DEFAULT_WITHDRAWAL_FEE]
