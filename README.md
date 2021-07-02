# AAVE & Curve StableCoin Yield Farming Strategy (Polygon Mainnet)

This mix is configured for use with [Ganache](https://github.com/trufflesuite/ganache-cli) on a [forked mainnet](https://eth-brownie.readthedocs.io/en/stable/network-management.html#using-a-forked-development-network).

## How it Works

### Deposit
The strategy takes [DAI](https://polygonscan.com/token/0x8f3cf7ad23cd3cadbd9735aff958023239c6a063) as deposit. The DAI is then deposited into 4 pools according to their respective allocation percentages: 
  1. [AAVE DAI pool](https://app.aave.com/markets)
  2. AAVE USDC Pool
  3. AAVE USDT Pool
  4. [CURVE aDAi-aUSDC-aUSDT Pool](https://polygon.curve.fi/aave)

The allocation percentages are calculated at strategy creation based on the APY of the pool. Then can be changed by the strategist later. Also, the required amoutn of DAI is converted into USDC & USDT for transfer into the USDC & USDT pools.

### Harvest & Compounding
The Matic rewards from each of the pools are first converted into DAI, and then deposited back into the strategy. 

The Curve pool also gives CRV rewards which is also converted into DAI and deposited back into the strategy.

### Withdrawing Funds
Withdrawing is a bit tricky here because we have funds in multiple pools. The way the algorithm is coded here is that when a user wants to withdraw funds the strategy will first try to withdraw funds from the AAVE-DAI pool, if not enough then it will withdraw the rest from the CURVE pool, then from the USDC-pool (converting the USDC into DAI on the way) and then the USDT pool.
 
## Expected Yield
As of July 2, 2021 the yields from the separate pools are as follows (including compounding of the matic/curve rewards daily):
  1. AAVE-DAI Pool -> 3.86% APY
  2. AAVE-USDC Pool -> 3.22% APY
  3. AAVE-USDT Pool -> 4.63% APY
  4. Curve Pool -> 10.67% APY

Taking into account their allocation percentages the net APY of the strategy will be<br>
### = (17% * 3.86%) + (14% * 3.22%) + (21% * 4.63%) + (48% * 10.67) = <strong>7.2% APY</strong>

## Documentation
A general template for the Strategy, Controller, Vault has generated taken from https://github.com/GalloDaSballo/badger-strategy-mix-v1

### The Vault Contract has 3 prime functions

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
info: Deposits the DAI held by the Vault Contract to the controller. The Controller will then deposit into the Strategy for yield-generation.

access: Only Authorized Actors
```

### The Controller Contract
The prime function of the Controller is to set, approve & remove Strategies for the Vault and act as a middleman between the Vault & the strategy(ies).

### The Strategy Contract (Most Important Functions)
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
info: reinvests the DAI held by the strategy back into the pools. Generally to be called after the harves() function.

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

<strong>changeAllocations(uint16[4] _allocations)</strong>
```
params: (_allocations) => list of allocations for the different pools. (where 100 will be 10%) with order being [dai, usdc, usdt, curve]

info: The values in the list must add up to 1000. This function may typically be called by the strategist when the APYs in the various pools changes to have a better allocation of the funds of the strategy for higher net APY.

access: Only Authorized Actors
```

## Installation and Setup

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

## Basic Use

To deploy the Strategy in a development environment:

1. Run Scripts for Deployment
```
  brownie run deploy
```
Deployment will set up a Vault, Controller and deploy your strategy

2. Testing

To run the tests:

```
brownie test
```

3. Run the test deployment in the console and interact with it
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
      'lpComponent': 0x028171bCA77440897B824Ca71D1c56caC55b68A3,
      'rewardToken': 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
      'sett': 0x6951b5Bd815043E3F842c1b026b0Fa888Cc2DD85,
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

When you are finished testing and ready to deploy to the mainnet:

1. [Import a keystore](https://eth-brownie.readthedocs.io/en/stable/account-management.html#importing-from-a-private-key) into Brownie for the account you wish to deploy from.
2. Run [`scripts/deploy.py`](scripts/deploy.py) with the following command

```bash
$ brownie run deployment --network mainnet
```

You will be prompted to enter your keystore password, and then the contract will be deployed.
