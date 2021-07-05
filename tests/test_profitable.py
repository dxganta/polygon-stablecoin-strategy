import brownie
from brownie import *
from helpers.constants import MaxUint256

MAX_BASIS = 10000


def test_is_profitable(deployed):
    deployer = deployed.deployer
    vault = deployed.vault
    controller = deployed.controller
    strategy = deployed.strategy
    want = deployed.want
    randomUser = accounts[6]

    initial_balance = want.balanceOf(deployer)

    settKeeper = accounts.at(vault.keeper(), force=True)

    # Deposit
    assert want.balanceOf(deployer) > 0

    depositAmount = int(want.balanceOf(deployer) * 0.8)
    assert depositAmount > 0

    want.approve(vault.address, MaxUint256, {"from": deployer})

    vault.deposit(depositAmount, {"from": deployer})

    # Earn
    with brownie.reverts("onlyAuthorizedActors"):
        vault.earn({"from": randomUser})

    min = vault.min()
    max = vault.max()
    remain = max - min

    vault.earn({"from": settKeeper})

    chain.sleep(86400*30)
    chain.mine(1)

    vault.withdrawAll({"from": deployer})

    ending_balance = want.balanceOf(deployer)

    print("Initial Balance")
    print(initial_balance)
    print("Ending Balance")
    print(ending_balance)

    assert ending_balance > initial_balance
