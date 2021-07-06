# AAVE & Curve StableCoin Yield Farming Strategy (Polygon Mainnet)

This mix is configured for use with [Ganache](https://github.com/trufflesuite/ganache-cli) on a [forked mainnet](https://eth-brownie.readthedocs.io/en/stable/network-management.html#using-a-forked-development-network).

## How it Works

### Deposit
The strategy takes [DAI](https://polygonscan.com/token/0x8f3cf7ad23cd3cadbd9735aff958023239c6a063) as deposit. 50% of the DAI is deposited into the [AAVE DAI Pool]((https://app.aave.com/reserve-overview/DAI-0x8f3cf7ad23cd3cadbd9735aff958023239c6a0630xd05e3e715d945b59290df0ae8ef85c1bdb684744)) and the other 50% is converted to USDC and deposited into the [AAVE USDC Pool](https://app.aave.com/reserve-overview/USDC-0x2791bca1f2de4661ed88a30c99a7a9449aa841740xd05e3e715d945b59290df0ae8ef85c1bdb684744).
Then a USDT loan is taken on the above deposit at 70% Loan to Collateral Ratio. The USDT is deposited into the [CURVE aDAi-aUSDC-aUSDT Pool](https://polygon.curve.fi/aave)

```
For e.g. Supoose the user deposits 10K DAI. 5K DAI is put into the AAVE DAI Pool & and the other 5K is converted to USDC and put into the USDC Pool. Then a 7K USDT Loan is taken on the the above collateral and put into the Curve Pool.
```


### Harvest & Compounding
The Matic rewards from the deposit & borrow pools are first converted into DAI, and then deposited back into the strategy. 

The Curve pool gives CRV rewards (in addition to WMATIC rewards) which is also converted into DAI and deposited back into the strategy.

### Withdrawing Funds
Withdrawing is a bit tricky here because we have funds in multiple pools & on top of that we have almost all of our deposits locked as collateral.<br>

First the strategy needs to withdraw the required amount of USDT from the curve pool and pay back the loan in AAVE to open up collateral for the user to withdraw. So, it burns the am3CRV tokens from the CURVE pool, withdraws USDT, and repays the loan. But since our loan is building up interest, what if the strategy doesn't have enough USDT in the CURVE pool to pay the loan? In that case, we convert DAI from our AAVE Deposit Pool to USDT to pay back the loan. In case, even the DAI is not enough, we use USDC.

Next, the strategy simply withdraws DAI from the AAVE-DAI Deposit Pool and sends them back to the user. If the AAVE-DAI pool doesnt have enough DAI to withdraw, then it withdraws USDC from the AAVE-USDC Pool, converts it to DAI and sends them to the user.
 
## Expected Yield
As of July 5, 2021 the net yields from the separate pools are as follows (including compounding of the matic/curve rewards daily):
  1. AAVE-DAI Deposit Pool -> 3.99% APY
  2. AAVE-USDC Deposit Pool -> 3.27% APY
  3. AAVE-USDT Borrow Pool -> <strong>-</strong>0.80% APY (-ve)
  4. Curve Pool -> 10.09% APY

Taking into account their allocation percentages the net APY of the strategy will be<br>
### = (50% * 3.99%) + (50% * 3.27%) - (70% * 0.80%) + (70% * 10.09) = <strong>10.13% APY</strong>

## Usage

### For Users (Callable by anyone)
A user just has to call the <strong>deposit()</strong> function in the Vault Contract to deposit his DAI. The Vault will provide him the required number of Vault Shares.

To withdraw his funds, the user just has to call the <strong>withdraw()</strong> function with the number of Vault shares he wants to liquidate and the Vault will return his deserved DAI as per the Vault shares.

(Ofcourse the user won't call the functions directly, but through a frontend component which will implement the above 2 functions through 2 buttons namely <strong>DEPOSIT</strong> & <strong>WITHDRAW</strong>)

### For Force Team (Below functions can only be called by authorized accounts)
The Force Team has to call the <strong>earn()</strong> function in the Vault Contract to deposit the DAI from the Vault Contract into the Strategy to start yield generation.

There is a <strong>harvest()</strong> function in the Strategy Contract which has to be called periodically by the Force Team (generally every month or week) to realize the WMATIC/CRV rewards & convert it to DAI.

After the harvest() you may call the <strong>tend()</strong> function which will deposit any idle DAI held by the strategy contract back into the pools for yield generation.

Or you can just call the <strong>compound()</strong> function which will call the harvest and tend functions together in one transaction.

(All the conversions & deposits are automated inside the strategy, you just have to call the above functions)

## Documentation
A general template for the Strategy, Controller, Vault has been generated from https://github.com/GalloDaSballo/badger-strategy-mix-v1

### The Vault Contract ([/contracts/deps/SettV3.sol](https://github.com/realdiganta/dbr-aave-polygon-strategy/blob/main/contracts/deps/SettV3.sol)) has 3 prime functions

<strong>deposit(uint256 _amount)</strong>
```
params: (_amount) => Amount of DAI

info: Deposits DAI into the Vault Contract & returns corresponding shares to the user
access: public
```

<strong>withdraw(uint256 _shares)</strong>
```
params: (_shares) => Number of Vault Shares held by user

info: Takes the shares from the user, burns them & returns corresponding DAI to the user
access: public
```

<strong>earn()</strong>
```
info: Deposits the DAI held by the Vault Contract into the Strategy for yield-generation.

access: Only Authorized Actors
```
<br>

### The Controller Contract ([/contracts/deps/Controller.sol](https://github.com/realdiganta/dbr-aave-polygon-strategy/blob/main/contracts/deps/Controller.sol))
The prime function of the Controller is to set, approve & remove Strategies for the Vault and act as a middleman between the Vault & the strategy(ies).
<br><br>
### The Strategy Contract ([/contracts/MyStrategy.sol](https://github.com/realdiganta/dbr-aave-polygon-strategy/blob/main/contracts/MyStrategy.sol)) :
 
<strong>deposit()</strong>
```
info: Deposits all DAI held by the strategy into the AAVE & Curve Pools (converting them into USDC & USDT as required) for yield generation.

access: Only Authorized Actors & Controller Contract.
```

<strong> harvest()</strong>
```
info: realizes Matic & Curve rewards and converts them to DAI.

access: Only Authorized Actors
```

<strong>tend()</strong>
```
info: reinvests the DAI held by the strategy back into the pools. Generally to be called after the harvest() function.

access: Only Authorized Actors
```

<strong>withdraw(uint256 _amount)</strong>
```
params: (_amount) => _amount in DAI to withdraw

info: withdraws funds from the strategy, unrolling from strategy positions as necessary
access: Only Controller
```

<strong>withdrawAll()</strong>
```
info: withdraws all the funds from the strategy.

access: Only Controller
```

<strong>compound()</strong>
```
info: calls the harvest & tend functions together in one transaction 

access: Only Authorized Actors
```

<strong>setLTCR(uint256 _ltcr)</strong>
```
params: (_ltcr) => The loan to collateral ratio for the USDT Loan (700 means 70%)

info: Maximum loan to collateral ratio is 75%. So set a number less than or equal to 750.

access: Only Authorized Actors
```

## Installation and Setup

1. Install Brownie & Ganache-CLI, if you haven't already.

2. Copy the .env.example file, and rename it to .env

3. Sign up for Infura and generate an API key. Store it in the WEB3_INFURA_PROJECT_ID environment variable.

4. Sign up for PolygonScan and generate an API key. This is required for fetching source codes of the polygon mainnet contracts we will be interacting with. Store the API key in the ETHERSCAN_TOKEN environment variable.

Install the dependencies in the package
```
## Javascript dependencies
npm i

## Python Dependencies
pip install virtualenv
virtualenv venv
source venv/bin/activate
pip install -r requirements.txt
```

Add Polygon to your local brownie networks
```
brownie networks import network-config.yaml
```

Increase the default balance of an account (since we are dealing with Matic here)
```
brownie networks modify polygon-main-fork default_balance="1000000 ether"
```

## Basic Use

To deploy the Strategy in a development environment:

1. Compile the contracts 
```
  brownie compile
```

2. Run Scripts for Deployment
```
  brownie run deploy
```
Deployment will set up a Vault, Controller and deploy your strategy


3. Run Tests
```
brownie test
```

4. Run the test deployment in the console and interact with it
```python
  brownie console
  deployed = run("deploy")

  ## Takes a minute or so
  Transaction sent: 0xa0009814d5bcd05130ad0a07a894a1add8aa3967658296303ea1f8eceac374a9
  Gas price: 0.0 gwei   Gas limit: 12000000   Nonce: 9
  UniswapV2Router02.swapExactETHForTokens confirmed - Block: 12614073   Gas used: 88626 (0.74%)

  ## Now you can interact with the contracts via the console
  >>> deployed
  {
      'controller': 0x602C71e4DAC47a042Ee7f46E0aee17F94A3bA0B6,
      'deployer': 0x66aB6D9362d4F35596279692F0251Db635165871,
      'rewardToken': 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
      'strategy': 0x9E4c14403d7d9A8A782044E86a93CAE09D7B2ac9,
      'vault': 0x6951b5Bd815043E3F842c1b026b0Fa888Cc2DD85,
      'want': 0x6B175474E89094C44Da98b954EedeAC495271d0F
  }
  >>>

  ## Deploy also uniswaps want to the deployer (accounts[0]), so you have funds to play with!
  >>> deployed.want.balanceOf(a[0])
  240545908911436022026

```
## Deployment

<strong>You can have a look at the deployment script at (/scripts/deploy.py)</strong>

When you are finished testing and ready to deploy to the mainnet:

1. [Import a keystore](https://eth-brownie.readthedocs.io/en/stable/account-management.html#importing-from-a-private-key) into Brownie for the account you wish to deploy from.
2. Run [`scripts/deploy.py`](scripts/deploy.py) with the following command

```bash
$ brownie run deployment --network mainnet
```

You will be prompted to enter your keystore password, and then the contract will be deployed.

## Notes
1. The Reward Gauge of the Curve Pool seems to be not giving any CRV/WMATIC rewards in the simulation on the forked polygon mainnet. This is because the [reward_gauge](https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/gauges/RewardsOnlyGauge.vy) contract of the curve pool has a manual component, where a particular authorized address called reward_receiver has to withdraw the rewards from a [rewards_claimer](https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/streamers/RewardClaimer.vy) contract to the rewards_gauge periodically. But this should not be a problem on the real deployment of the contract to the real Polygon Mainnet.

2. We are calling a Vault, Sett here.