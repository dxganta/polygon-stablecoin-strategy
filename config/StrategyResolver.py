from helpers.StrategyCoreResolver import StrategyCoreResolver
from rich.console import Console

console = Console()


class StrategyResolver(StrategyCoreResolver):
    def hook_after_confirm_withdraw(self, before, after, params):
        """
            Specifies extra check for ordinary operation on withdrawal
            Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True
    def hook_after_confirm_deposit(self, before, after, params):
        """
            Specifies extra check for ordinary operation on deposit
            Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True

    def hook_after_earn(self, before, after, params):
        """
            Specifies extra check for ordinary operation on earn
            Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True
        # assert after.balances("want", "amDAI") + after.balances("want", "amUSDC") + after.balances("want", "amUSDT") < before.balances("want", "amDAI") + before.balances("want", "amUSDC") + before.balances("want", "amUSDT")

    def confirm_harvest(self, before, after, tx):
        """
            Verfies that the Harvest produced yield and fees
        """
        console.print("=== Compare Harvest ===")
        self.manager.printCompare(before, after)
        self.confirm_harvest_state(before, after, tx)

        valueGained = after.get("sett.pricePerFullShare") > before.get(
            "sett.pricePerFullShare"
        )

        # Strategist should earn if fee is enabled and value was generated
        if before.get("strategy.performanceFeeStrategist") > 0 and valueGained:
            assert after.balances("want", "strategist") > before.balances(
                "want", "strategist"
            )

        # Strategist should earn if fee is enabled and value was generated
        if before.get("strategy.performanceFeeGovernance") > 0 and valueGained:
            assert after.balances("want", "governanceRewards") > before.balances(
                "want", "governanceRewards"
            )

    def confirm_tend(self, before, after, tx):
        """
        Tend Should;
        - Increase the number of staked tended tokens in the strategy-specific mechanism
        - Reduce the number of tended tokens in the Strategy to zero

        (Strategy Must Implement)
        """
        assert after.get("strategy.isTendable") == True

        print("strategy.balanceOfWant")
        print(before.get("strategy.balanceOfWant"))

        if (before.get("strategy.balanceOfWant") > 0):
            assert after.get("strategy.balanceOfWant") == 0

            assert after.get("strategy.balanceOfPool") > before.get(
                "strategy.balanceOfPool")

    def get_strategy_destinations(self):
        """
        Track balances for all strategy implementations
        (Strategy Must Implement)
        """
        strategy = self.manager.strategy
        return {
            "amDAI": strategy.amDAI(),
            "amUSDC": strategy.amUSDC(),
            "amUSDT": strategy.amUSDT()
        }
