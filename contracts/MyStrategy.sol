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

import {
    BaseStrategy
} from "../deps/BaseStrategy.sol";

contract MyStrategy is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    address public amDAI; // Token we provide liquidity with
    address public amUSDC;
    address public amUSDT;
    address public reward; // Token we farm and swap to want / amDAI

    address public constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant am3CRV = 0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171;

    // the same indexes are for amDai, amUSDC, amUSDT for curve exchanges
    int128 public constant CURVE_DAI_INDEX = 0;
    int128 public constant CURVE_USDC_INDEX = 1;
    int128 public constant CURVE_USDT_INDEX = 2;


    address public constant LENDING_POOL = 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf;
    address public constant INCENTIVES_CONTROLLER = 0x357D51124f59836DeD84c8a1730D72B749d8BC23;
    address public constant QUICKSWAP_ROUTER = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant CURVE_POOL = 0x445FE580eF8d70FF569aB36e80c647af338db351;

    // allocations to different pools in percent
    uint16 public constant ALLOC_DECIMALS = 1000;
    uint16 public daiPoolPercent = 350;
    uint16 public usdcPoolPercent = 280;
    uint16 public usdtPoolPercent = 370;

    function initialize(
        address _governance,
        address _strategist,
        address _controller,
        address _keeper,
        address _guardian,
        address[5] memory _wantConfig,
        uint256[3] memory _feeConfig
    ) public initializer {
        __BaseStrategy_init(_governance, _strategist, _controller, _keeper, _guardian);

        /// @dev Add config here
        want = _wantConfig[0];
        amDAI = _wantConfig[1];
        amUSDC = _wantConfig[2];
        amUSDT = _wantConfig[3];
        reward = _wantConfig[4];

        performanceFeeGovernance = _feeConfig[0];
        performanceFeeStrategist = _feeConfig[1];
        withdrawalFee = _feeConfig[2];

        /// @dev do one off approvals here
        IERC20Upgradeable(want).safeApprove(LENDING_POOL, type(uint256).max);
        IERC20Upgradeable(usdc).safeApprove(LENDING_POOL, type(uint256).max);
        IERC20Upgradeable(usdt).safeApprove(LENDING_POOL, type(uint256).max);

        IERC20Upgradeable(reward).safeApprove(QUICKSWAP_ROUTER, type(uint256).max);
        IERC20Upgradeable(want).safeApprove(CURVE_POOL, type(uint256).max);

        IERC20Upgradeable(amDAI).safeApprove(CURVE_POOL, type(uint256).max);
        IERC20Upgradeable(amUSDC).safeApprove(CURVE_POOL, type(uint256).max);
        IERC20Upgradeable(amUSDT).safeApprove(CURVE_POOL, type(uint256).max);
    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external override pure returns (string memory) {
        return "AAVE-Polygon-CURVE";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev Balance of want currently held in strategy positions
    function balanceOfPool() public override view returns (uint256) {
        return IERC20Upgradeable(amDAI).balanceOf(address(this))
        .add(IERC20Upgradeable(amUSDC).balanceOf(address(this)))
        .add(IERC20Upgradeable(amUSDT).balanceOf(address(this)));
    }

    /// @dev Balance of a particular token fot this contract
    function balanceOfToken(address _token) public view returns (uint256) {
        return IERC20Upgradeable(_token).balanceOf(address(this));
    }
    
    /// @dev Returns true if this strategy requires tending
    function isTendable() public override view returns (bool) {
        return true;
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
        uint256 usdcAmount = _amount.mul(usdcPoolPercent).div(ALLOC_DECIMALS);
        uint256 usdtAmount = _amount.mul(usdtPoolPercent).div(ALLOC_DECIMALS);
        uint256 daiAmount = _amount.sub(usdcAmount.add(usdtAmount));

        // dai to usdc
       usdcAmount =  ICurveExchange(CURVE_POOL).exchange_underlying(CURVE_DAI_INDEX, CURVE_USDC_INDEX, usdcAmount, 1);

        // dai to usdt
       usdtAmount =  ICurveExchange(CURVE_POOL).exchange_underlying(CURVE_DAI_INDEX, CURVE_USDT_INDEX, usdtAmount, 1);

        // deposit to AAVE Lending Pool and get back amDAI, amUSDC, amUSDT tokens
        ILendingPool(LENDING_POOL).deposit(want, daiAmount, address(this), 0);
        ILendingPool(LENDING_POOL).deposit(usdc, usdcAmount, address(this), 0);
        ILendingPool(LENDING_POOL).deposit(usdt, usdtAmount, address(this), 0);

        // deposit the amDai, amUSDC, amUSDT into the CURVE AAVE pool
        // gives back am3CRV LP TOKENS  
        ICurveExchange(CURVE_POOL).add_liquidity([
        balanceOfToken(amDAI),
        balanceOfToken(amUSDC),
        balanceOfToken(amUSDT)
        ], 1);
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        ILendingPool(LENDING_POOL).withdraw(want, balanceOfPool(), address(this));
    }
    /// @dev withdraw the specified amount of want, liquidate from amDAI to want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        if (_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }
        ILendingPool(LENDING_POOL).withdraw(want, _amount, address(this));
        return _amount;
    }

    /// @dev Harvest from strategy mechanics, realizing increase in underlying position
    function harvest() external whenNotPaused returns (uint256 harvested) {
        _onlyAuthorizedActors();

        uint256 _before = IERC20Upgradeable(want).balanceOf(address(this));

        // Get the WMATIC rewards from the AAVE pool into this contract
        address[] memory assets = new address[](1);
        assets[0] = amDAI;
        IAaveIncentivesController(INCENTIVES_CONTROLLER).claimRewards(assets, type(uint256).max, address(this));

        // TODO: get WMATIC rewards from CURVE pool

        uint256 rewardsAmount = IERC20Upgradeable(reward).balanceOf(address(this));
        if (rewardsAmount == 0) {
                return 0;
        }

         // Swap WMATIC-usdc then usdc-DAI using quickswap router
        address[] memory path = new address[](3);
        path[0] = reward;
        path[1] = usdc;
        path[2] = want;
        IUniswapRouterV2(QUICKSWAP_ROUTER).swapExactTokensForTokens(rewardsAmount, 1, path, address(this), now);

        uint256 earned = IERC20Upgradeable(want).balanceOf(address(this)).sub(_before);

        /// @notice Keep this in so you get paid!
        (uint256 governancePerformanceFee, uint256 strategistPerformanceFee) = _processPerformanceFees(earned);

        /// @dev Harvest event that every strategy MUST have, see BaseStrategy
        emit Harvest(earned, block.number);

        return earned;
    }

    // Alternative Harvest with Price received from harvester, used to avoid exessive front-running
    function harvest(uint256 price) external whenNotPaused returns (uint256 harvested) {

    }

    /// @dev Rebalance, Compound or Pay off debt here
    function tend() external whenNotPaused {
        _onlyAuthorizedActors();

        if (balanceOfWant() > 0) {
            _deposit(balanceOfWant());
        }
    }


    /// ===== Internal Helper Functions =====
    
    /// @dev used to manage the governance and strategist fee, make sure to use it to get paid!
    function _processPerformanceFees(uint256 _amount) internal returns (uint256 governancePerformanceFee, uint256 strategistPerformanceFee) {
        governancePerformanceFee = _processFee(want, _amount, performanceFeeGovernance, IController(controller).rewards());

        strategistPerformanceFee = _processFee(want, _amount, performanceFeeStrategist, strategist);
    }
}
