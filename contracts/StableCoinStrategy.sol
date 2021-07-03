// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/badger/IController.sol";
import "../interfaces/aave/ILendingPool.sol";
import "../interfaces/aave/IAaveIncentivesController.sol";
import "../interfaces/uniswap/IUniswapRouterV2.sol";
import {ICurveExchange} from "../interfaces/curve/ICurveExchange.sol";
import "../interfaces/curve/IRewardsOnlyGauge.sol";

import {
    BaseStrategy
} from "../deps/BaseStrategy.sol";

contract MyStrategy is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    address public constant amDAI = 0x27F8D03b3a2196956ED754baDc28D73be8830A6e; // Token we provide liquidity with
    address public constant amUSDC = 0x1a13F4Ca1d028320A707D99520AbFefca3998b7F;
    address public constant amUSDT = 0x60D55F02A771d515e077c9C2403a1ef324885CeC;
    address public constant reward = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // WMATIC

    address public constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant am3CRV = 0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171;
    address public constant crv = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;

    // the same indexes are for amDai, amUSDC, amUSDT for curve exchanges
    int128 public constant CURVE_DAI_INDEX = 0;
    int128 public constant CURVE_USDC_INDEX = 1;
    int128 public constant CURVE_USDT_INDEX = 2;


    address public constant LENDING_POOL = 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf;
    address public constant INCENTIVES_CONTROLLER = 0x357D51124f59836DeD84c8a1730D72B749d8BC23;
    address public constant QUICKSWAP_ROUTER = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant CURVE_POOL = 0x445FE580eF8d70FF569aB36e80c647af338db351;
    address public constant CURVE_REWARDS_GAUGE = 0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c;

    // allocations to different pools in percent
    uint16 public constant ALLOC_DECIMALS = 1000;
    uint16 public daiPoolPercent = 200;
    uint16 public usdcPoolPercent = 160;
    uint16 public usdtPoolPercent = 250;
    uint16 public curvePoolPercent = 390;

    uint256 public am3CRVBalance = 0;

    function initialize(
        address _governance,
        address _strategist,
        address _controller,
        address _keeper,
        address _guardian,
        address _want
    ) public initializer {
        __BaseStrategy_init(_governance, _strategist, _controller, _keeper, _guardian);

        want = _want;

        /// @dev do one off approvals here
        IERC20Upgradeable(want).safeApprove(LENDING_POOL, type(uint256).max);
        IERC20Upgradeable(usdc).safeApprove(LENDING_POOL, type(uint256).max);
        IERC20Upgradeable(usdt).safeApprove(LENDING_POOL, type(uint256).max);

        IERC20Upgradeable(reward).safeApprove(QUICKSWAP_ROUTER, type(uint256).max);
        IERC20Upgradeable(crv).safeApprove(QUICKSWAP_ROUTER, type(uint256).max);
        IERC20Upgradeable(usdc).safeApprove(QUICKSWAP_ROUTER, type(uint256).max);
        IERC20Upgradeable(want).safeApprove(CURVE_POOL, type(uint256).max);
        IERC20Upgradeable(usdc).safeApprove(CURVE_POOL, type(uint256).max);
        IERC20Upgradeable(usdt).safeApprove(CURVE_POOL, type(uint256).max);
        IERC20Upgradeable(am3CRV).safeApprove(CURVE_REWARDS_GAUGE, type(uint256).max);
    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external override pure returns (string memory) {
        return "AAVE-Polygon-CURVE StableCoin Strategy";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev Balance of want currently held in strategy positions
    /// @notice since usdc & usdt has 6 decimals, multiply their balance with 10^12
    /// to get an accurate representation of balanceOfPool in DAI terms
    function balanceOfPool() public override view returns (uint256) {
        return IERC20Upgradeable(amDAI).balanceOf(address(this))
        .add(IERC20Upgradeable(amUSDC).balanceOf(address(this)).mul(10**12))
        .add(IERC20Upgradeable(amUSDT).balanceOf(address(this)).mul(10**12))
        .add(am3CRVBalance);
    }

    /// @dev Balance of a particular token fot this contract
    function balanceOfToken(address _token) public view returns (uint256) {
        return IERC20Upgradeable(_token).balanceOf(address(this));
    }
    

    // @dev These are the tokens that cannot be moved except by the vault
    function getProtectedTokens() public override view returns (address[] memory) {
        address[] memory protectedTokens = new address[](8);
        protectedTokens[0] = want;
        protectedTokens[1] = usdc;
        protectedTokens[2] = usdt; 
        protectedTokens[3] = amDAI;
        protectedTokens[4] = amUSDC;
        protectedTokens[5] = amUSDT;
        protectedTokens[6] = reward;
        protectedTokens[7] = am3CRV;
        return protectedTokens;
    }

    /// ===== Internal Core Implementations =====

    /// @dev security check to avoid moving tokens that would cause a rugpull, edit based on strat
    function _onlyNotProtectedTokens(address _asset) internal override {
        address[] memory protectedTokens = getProtectedTokens();

        for(uint256 x = 0; x < protectedTokens.length; x++){
            require(address(protectedTokens[x]) != _asset, "Asset is protected");
        }
    }


    /// @dev invest the amount of want
    /// @notice When this function is called, the controller has already sent want to this
    /// @notice Just get the current balance and then invest accordingly
    function _deposit(uint256 _amount) internal override {
        // get respective amount of tokens for each pool according to their allocation percentage
        uint256 usdcAmt = _amount.mul(usdcPoolPercent).div(ALLOC_DECIMALS);
        uint256 usdtAmt = _amount.mul(usdtPoolPercent).div(ALLOC_DECIMALS);
        uint256 daiAmt = _amount.mul(daiPoolPercent).div(ALLOC_DECIMALS);

        uint256 curveDaiAmt = _amount.sub(usdcAmt.add(usdtAmt).add(daiAmt));

        // dai to usdc (using curve exchange)
       usdcAmt =  ICurveExchange(CURVE_POOL).exchange_underlying(CURVE_DAI_INDEX, CURVE_USDC_INDEX, usdcAmt, 1);
        // dai to usdt
       usdtAmt =  ICurveExchange(CURVE_POOL).exchange_underlying(CURVE_DAI_INDEX, CURVE_USDT_INDEX, usdtAmt, 1);

        // deposit remaining dai to CURVE Pool, getting back am3CRV token
       uint256 _am3CRVamt =  ICurveExchange(CURVE_POOL).add_liquidity([curveDaiAmt, 0,0 ], 1, true);
       am3CRVBalance = am3CRVBalance.add(_am3CRVamt);
        // also stake the am3CRV tokens to the curve reward receiver to get WMATIC & CRV rewards
        IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).deposit(_am3CRVamt, address(this), true);

        // deposit to AAVE Lending Pool and get back amDAI, amUSDC, amUSDT tokens
        ILendingPool(LENDING_POOL).deposit(want, daiAmt, address(this), 0);
        ILendingPool(LENDING_POOL).deposit(usdc, usdcAmt, address(this), 0);
        ILendingPool(LENDING_POOL).deposit(usdt, usdtAmt, address(this), 0);
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        _withdrawSome(balanceOfPool());
        emit WithdrawAll(balanceOfPool());
    }

    /// @dev withdraw the specified amount of want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        uint256 _pool = balanceOfPool();
        if (_amount > _pool) {
            _amount = _pool;
        }

        uint256 _sub = _amount;

       _sub =  _withDrawFromAAVEPool(amDAI, want, 1, _sub, 0);
       _sub = _withDrawFromCurvePool(_sub);
       _sub =  _withDrawFromAAVEPool(amUSDC, usdc, 10**12, _sub, CURVE_USDC_INDEX);
       _sub = _withDrawFromAAVEPool(amUSDT, usdt, 10**12, _sub, CURVE_USDT_INDEX );

       emit Withdraw(_amount);

        return _amount;
    }


    /// @param _d => number to make up for the difference in decimals between dai & usdc/usdt
    function _withDrawFromAAVEPool(address _aToken, address _token, uint256 _d, uint256 _amount, int128 _exIndex) internal returns (uint256) {
        uint256 _balance = balanceOfToken(_aToken).mul(_d);
        if (_amount > 0 && _balance > 0) {
            uint256 _exAmt;
            if (_balance >= _amount) {
               _exAmt =  ILendingPool(LENDING_POOL).withdraw(_token, _amount.div(_d), address(this));
                _amount = 0;
            } else {
                _amount = _amount.sub(_balance);
               _exAmt =  ILendingPool(LENDING_POOL).withdraw(_token, _balance.div(_d), address(this));
            }

            // exchange to DAI (for usdc & usdt pools)
            if (_exIndex != 0) {
                ICurveExchange(CURVE_POOL).exchange_underlying(_exIndex,CURVE_DAI_INDEX, _exAmt, 1);
            }
        }
        return _amount;
    }

    function _withDrawFromCurvePool(uint256 _amount) internal returns (uint256) {
        uint256 _balance = am3CRVBalance;
        if (_amount > 0 && _balance > 0) {
            if (_balance >= _amount) {
                // first withdraw am3CRV from curve rewards pool
                IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).withdraw(_amount,true);
                // then burn am3CRV and withdraw DAI from CURVE StableSwap pool
                ICurveExchange(CURVE_POOL).remove_liquidity_one_coin(_amount, CURVE_DAI_INDEX, 1, true);
                _amount = 0;
                am3CRVBalance = am3CRVBalance.sub(_amount);
            } else {
                IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).withdraw(_balance, true);
                ICurveExchange(CURVE_POOL).remove_liquidity_one_coin(_balance, CURVE_DAI_INDEX, 1, true);
                am3CRVBalance = 0;
                _amount = _amount.sub(_balance);
            }
        }
        return _amount;
    }

    /// @dev Harvest from strategy mechanics, realizing increase in underlying position
    function harvest() external whenNotPaused returns (uint256 harvested) {
        _onlyAuthorizedActors();

        uint256 _before = IERC20Upgradeable(want).balanceOf(address(this));

        // Get the WMATIC rewards from the AAVE pool
        address[] memory assets = new address[](3);
        assets[0] = amDAI;
        assets[1] = amUSDC;
        assets[2] = amUSDT;
        IAaveIncentivesController(INCENTIVES_CONTROLLER).claimRewards(assets, type(uint256).max, address(this));

        // Get WMATIC & CRV rewards from CURVE pool
        IRewardsOnlyGauge(CURVE_REWARDS_GAUGE).claim_rewards(address(this), address(this));

        uint256 rewardsAmount = balanceOfToken(reward);
        if (rewardsAmount == 0) {
                return 0;
        }
         // Swap WMATIC-USDC then USDC-DAI
        address[] memory path = new address[](3);
        path[0] = reward;
        path[1] = usdc;
        path[2] = want;
        IUniswapRouterV2(QUICKSWAP_ROUTER).swapExactTokensForTokens(rewardsAmount, 1, path, address(this), now);

        // Swap CRV to DAI
        uint256 crvAmt = balanceOfToken(crv);
        if (crvAmt > 0) {
            path = new address[](2);
            path[0] = crv;
            path[1] = want;
            IUniswapRouterV2(QUICKSWAP_ROUTER).swapExactTokensForTokens(crvAmt, 1, path, address(this), now);
        }

        uint256 earned = IERC20Upgradeable(want).balanceOf(address(this)).sub(_before);

        /// @dev Harvest event that every strategy MUST have, see BaseStrategy
        emit Harvest(earned, block.number);

        return earned;
    }

    /// @dev Rebalance, Compound or Pay off debt here
    function tend() external whenNotPaused {
        _onlyAuthorizedActors();

        if (balanceOfWant() > 0) {
            _deposit(balanceOfWant());
        }
        emit Tend(balanceOfWant());
    }

    function chanceAllocations(uint16[4] memory _allocations) external {
        _onlyAuthorizedActors();
        require (_allocations[0] + _allocations[1] + _allocations[2] + _allocations[3] == 1000);
        daiPoolPercent = _allocations[0];
        usdcPoolPercent = _allocations[1];
        usdtPoolPercent = _allocations[2];
        curvePoolPercent = _allocations[3];
    }
}
