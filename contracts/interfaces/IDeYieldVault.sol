// SPDX: License-Identifier: MIT

interface IDeYieldVault {
    struct AssetInfo {
        address token;
        uint256 totalDeposited;
        uint256 totalYEETPendingRedeem;
        uint256 totalAmountInvested;
    }
    struct RedeemRequest {
        uint256 redeemRequestId;
        address user;
        address assetOut;
        uint256 amountIn;
        uint256 createAt;
        bool executed;
    }
    event AssetWhitelisted(address indexed asset);
    event AssetUnwhitelisted(address indexed asset);
    event Deposited(
        address indexed _user,
        address indexed token,
        uint256 amount,
        uint256 amountYEET
    );
    event RedeemRequestCreated(
        address indexed user,
        uint256 indexed redeemRequestId,
        address indexed assetOut,
        uint256 amountIn
    );
    event RedeemRequestExecuted(
        address indexed user,
        uint256 indexed redeemRequestId,
        address indexed assetOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event RedeemRequestCanceled(
        address indexed user,
        uint256 indexed redeemRequestId,
        address indexed assetOut,
        uint256 amountIn
    );
    event FoundationWithdrawForInvest(address indexed token, uint256 amount);
    event FoundationPayback(address indexed token, uint256 amount);
    event FoundationDeposited(address indexed token, uint256 amount);
    event IncreaseXUSDSupply(uint256 amount);
    event AddReward(address indexed token, uint256 amount);
    event PendingExecutionTimeSet(uint256 time);
    event ReserveFactorSet(uint256 reserveFactor);
    event FeeSet(uint256 vaultFee, uint256 foundationFee);

    function initialize(
        address _deYieldAddressesProvider,
        address _owner
    ) external;
    function deposit(address _token, uint256 _amount) external;

    function createRedeemRequest(address _assetOut, uint256 _amountIn) external;
    function cancelRedeemRequest(uint256 _redeemRequestId) external;
    function executeRedeemRequest(uint256 _redeemRequestId) external;

    function foundationWithdrawForInvest(
        address _token,
        uint256 _amount
    ) external;

    function foundationPayback(address _token, uint256 _amount) external;

    function foundationDeposit(address _token, uint256 _amount) external;

    function increaseXUSDSupply(uint256 _amount) external;

    function setWhitelistedAsset(address _asset, bool _isSet) external;

    function setPendingExecutionTime(uint256 _time) external;
    function setReserveFactor(uint256 _reserveFactor) external;
    function setFee(uint256 _vaultFee, uint256 _foundationFee) external;
    function isWhitelistedAsset(address _asset) external view returns (bool);

    function getAmountOut(
        address _asset,
        uint256 _amountIn
    ) external view returns (uint256);

    function getAmountIn(
        address _asset,
        uint256 _amountOut
    ) external view returns (uint256);
    function estimateAmountRedeem(
        address _asset,
        uint256 _amountYeet
    ) external view returns (uint256);
    function getWhitelistedAssets() external view returns (address[] memory);

    function getPendingRedeemRequests(
        address _user,
        uint256 _offset,
        uint256 _limit
    ) external view returns (RedeemRequest[] memory);

    function getPendingRedeemRequestsLength(
        address _user
    ) external view returns (uint256);

    function getExcutedRedeemRequests(
        address _user,
        uint256 _offset,
        uint256 _limit
    ) external view returns (RedeemRequest[] memory);

    function getExcutedRedeemRequestsLength(
        address _user
    ) external view returns (uint256);

    function getAssetsInfo() external view returns (AssetInfo[] memory);
}
