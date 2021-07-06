import brownie
from brownie import *
from helpers.constants import MaxUint256
from helpers.time import days


def test_deposit_withdraw_single_user_flow(deployer, vault, controller, strategy, want, settKeeper):
    # Setup
    randomUser = accounts[6]
    # End Setup

    # Deposit
    assert want.balanceOf(deployer) > 0

    depositAmount = int(want.balanceOf(deployer))
    assert depositAmount > 0

    want.approve(vault.address, MaxUint256, {"from": deployer})

    vault.deposit(depositAmount, {"from": deployer})

    shares = vault.balanceOf(deployer)

    # Earn
    with brownie.reverts("onlyAuthorizedActors"):
        vault.earn({"from": randomUser})

    vault.earn({"from": settKeeper})

    chain.sleep(days(15))
    chain.mine(1)

    vault.withdraw(shares // 2, {"from": deployer})

    chain.sleep(days(15))
    chain.mine(1)

    vault.withdraw(shares // 2 - 1, {"from": deployer})

    newBalance = int(want.balanceOf(deployer))

    assert(newBalance > depositAmount)


def test_single_user_harvest_flow(deployer, vault, controller, strategy, want, settKeeper, strategyKeeper):
    # Setup
    randomUser = accounts[6]
    startingBalance = want.balanceOf(deployer)
    depositAmount = startingBalance // 2
    assert startingBalance >= depositAmount
    assert startingBalance >= 0
    # End Setup

    # Deposit
    want.approve(vault, MaxUint256, {"from": deployer})
    vault.deposit(depositAmount, {"from": deployer})
    shares = vault.balanceOf(deployer)

    assert want.balanceOf(vault) > 0
    print("want.balanceOf(vault)", want.balanceOf(vault))

    # Earn
    vault.earn({"from": settKeeper})

    assert want.balanceOf(vault) == 0

    prevBalanceOfPool = strategy.balanceOfPool()

    # only authorized actors should be able to call compound function
    with brownie.reverts("onlyAuthorizedActors"):
        strategy.compound({"from": randomUser})

    chain.sleep(days(15))
    chain.mine(1)

    strategy.compound({"from": strategyKeeper})

    newBalanceOfPool = strategy.balanceOfPool()

    # balance of pool of strategy increases after compounding
    assert newBalanceOfPool > prevBalanceOfPool

    vault.withdraw(shares // 2, {"from": deployer})

    chain.sleep(days(3))
    chain.mine()

    strategy.compound({"from": strategyKeeper})
    vault.withdraw(shares // 2 - 1, {"from": deployer})

    # user should make a profit
    assert want.balanceOf(deployer) > startingBalance


def test_migrate_single_user(deployer, vault,  controller, strategy, want, strategist):
    # Setup
    randomUser = accounts[6]

    startingBalance = want.balanceOf(deployer)
    depositAmount = startingBalance // 2
    assert startingBalance >= depositAmount
    # End Setup

    # Deposit
    want.approve(vault, MaxUint256, {"from": deployer})
    vault.deposit(depositAmount, {"from": deployer})

    chain.sleep(days(1))
    chain.mine()

    vault.earn({"from": strategist})

    chain.snapshot()

    # Test no harvests
    chain.sleep(days(2))
    chain.mine()

    before = {"settWant": want.balanceOf(
        vault), "stratWant": strategy.balanceOf()}

    with brownie.reverts():
        controller.withdrawAll(strategy.want(), {"from": randomUser})

    controller.withdrawAll(strategy.want(), {"from": deployer})

    after = {"settWant": want.balanceOf(
        vault), "stratWant": strategy.balanceOf()}

    assert after["settWant"] > before["settWant"]
    assert after["stratWant"] < before["stratWant"]
    assert after["stratWant"] == 0

    # Test tend only
    chain.revert()

    chain.sleep(days(2))
    chain.mine()

    strategy.tend({"from": deployer})

    before = {"settWant": want.balanceOf(
        vault), "stratWant": strategy.balanceOf()}

    with brownie.reverts():
        controller.withdrawAll(strategy.want(), {"from": randomUser})

    controller.withdrawAll(strategy.want(), {"from": deployer})

    after = {"settWant": want.balanceOf(
        vault), "stratWant": strategy.balanceOf()}

    assert after["settWant"] > before["settWant"]
    assert after["stratWant"] < before["stratWant"]
    assert after["stratWant"] == 0

    # Test harvest
    chain.revert()

    chain.sleep(days(1))
    chain.mine()

    strategy.tend({"from": deployer})

    chain.sleep(days(1))
    chain.mine()

    before = {
        "settWant": want.balanceOf(vault),
        "stratWant": strategy.balanceOf(),
        "rewardsWant": want.balanceOf(controller.rewards()),
    }

    with brownie.reverts():
        controller.withdrawAll(strategy.want(), {"from": randomUser})

    controller.withdrawAll(strategy.want(), {"from": deployer})

    after = {"settWant": want.balanceOf(
        vault), "stratWant": strategy.balanceOf()}

    assert after["settWant"] > before["settWant"]
    assert after["stratWant"] < before["stratWant"]
    assert after["stratWant"] == 0


def test_withdrawAll_removes_all(deployer, vault,  controller, strategy, want, strategist):
    '''
        Test that withdrawAll makes the balance of all assets equal to zero
    '''
    want.approve(vault, MaxUint256, {"from": deployer})
    vault.depositAll({"from": deployer})

    vault.earn({'from': strategist})

    chain.sleep(days(15))
    chain.mine()

    strategy.compound({'from': strategist})

    chain.sleep(days(5))
    chain.mine()

    vault.withdrawAll({'from': deployer})

    assert strategy.balanceOfWant() == 0
    assert strategy.balanceOfToken(strategy.usdc()) == 0
    assert strategy.balanceOfToken(strategy.amUSDC()) == 0
    assert strategy.balanceOfToken(strategy.amDAI()) == 0
    assert strategy.balanceOfToken(strategy.debtUSDT()) == 0
    assert strategy.am3CRVBalance() == 0
