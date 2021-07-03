from brownie import *
from config import (
    BADGER_DEV_MULTISIG,
    WANT,
    REWARD_TOKEN
)
from dotmap import DotMap


def main():
    return deploy()


def deploy():
    """
      Deploys, vault, controller and strats and wires them up for you to test
    """
    deployer = accounts[0]

    strategist = deployer
    keeper = deployer
    guardian = deployer

    governance = accounts.at(BADGER_DEV_MULTISIG, force=True)

    controller = Controller.deploy({"from": deployer})
    controller.initialize(
        BADGER_DEV_MULTISIG,
        strategist,
        keeper,
        BADGER_DEV_MULTISIG
    )

    sett = SettV3.deploy({"from": deployer})
    sett.initialize(
        WANT,
        controller,
        BADGER_DEV_MULTISIG,
        keeper,
        guardian,
        False,
        "prefix",
        "PREFIX"
    )

    sett.unpause({"from": governance})
    controller.setVault(WANT, sett)

    # TODO: Add guest list once we find compatible, tested, contract
    # guestList = VipCappedGuestListWrapperUpgradeable.deploy({"from": deployer})
    # guestList.initialize(sett, {"from": deployer})
    # guestList.setGuests([deployer], [True])
    # guestList.setUserDepositCap(100000000)
    # sett.setGuestList(guestList, {"from": governance})

    #  Start up Strategy
    strategy = MyStrategy.deploy({"from": deployer})
    strategy.initialize(
        BADGER_DEV_MULTISIG,
        strategist,
        controller,
        keeper,
        guardian,
        WANT
    )

    # Tool that verifies bytecode (run independetly) <- Webapp for anyone to verify

    # Set up tokens
    want = interface.IERC20(WANT)

    rewardToken = interface.IERC20(REWARD_TOKEN)

    #  Wire up Controller to Strategy
    controller.approveStrategy(WANT, strategy, {"from": governance})
    controller.setStrategy(WANT, strategy, {"from": deployer})

    # Quickswap some tokens here
    router = Contract.from_explorer(
        "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff")
    router.swapExactETHForTokens(
        0,  #  Mint out
        ["0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", WANT],
        deployer,
        9999999999999999,
        {"from": deployer, "value": 10000 * 10**18}
    )

    return DotMap(
        deployer=deployer,
        controller=controller,
        vault=sett,
        sett=sett,
        strategy=strategy,
        # guestList=guestList,
        want=want,
        rewardToken=rewardToken
    )
