import brownie
from brownie import *
from helpers.constants import MaxUint256
from helpers.SnapshotManager import SnapshotManager
from helpers.time import days

"""
  TODO: Put your tests here to prove the strat is good!
  See test_harvest_flow, for the basic tests
  See test_strategy_permissions, for tests at the permissions level
"""


def test_my_custom_test(deployed):
    dai = interface.IERC20Upgradeable(
        "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063")
    dai_balance_deployer = dai.balanceOf(deployed.deployer.address)

    # transfer dai from deployer to strategy
    dai.transfer(deployed.strategy.address, dai_balance_deployer,
                 {"from": deployed.deployer.address})

    assert deployed.strategy.balanceOfDai() == dai_balance_deployer
    assert deployed.strategy.balanceOfUSDC() == 0

    # transfer dai to usdc
    deployed.strategy.testCurve(dai_balance_deployer)

    print(deployed.strategy.balanceOfUSDC())

    assert deployed.strategy.balanceOfUSDC() > 0
