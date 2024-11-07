// SPDX: License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IYEET.sol";
import "../interfaces/IXUSD.sol";
import "../interfaces/IDeYieldVault.sol";
import "../interfaces/IDeYieldAddressesProvider.sol";
import "../interfaces/IDeYieldOracle.sol";

contract DeYieldVault is IDeYieldVault, AccessControlUpgradeable {
    bytes32 public constant FOUNDATION_ROLE = keccak256("FOUNDATION_ROLE");
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    uint256 public constant MINIMUM_AMOUNT = 10 ether;
    uint256 public PRECISION;
    uint256 public reserveFactor;
    uint256 public vaultFee;
    uint256 public foundationFee;

    uint256 public pendingExecutionTime;
    address public deYieldAddressesProvider;

    EnumerableSetUpgradeable.AddressSet whitelistedAssets;
    RedeemRequest[] public redeemRequests;

    mapping(address => EnumerableSetUpgradeable.UintSet) pendingRedeemRequests;
    mapping(address => EnumerableSetUpgradeable.UintSet) executedRedeemRequests;
    mapping(address => AssetInfo) public assets;

    function initialize(
        address _deYieldAddressesProvider,
        address _owner
    ) external override initializer {
        require(
            _deYieldAddressesProvider != address(0),
            "DeYieldVault: invalid addresses provider"
        );
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(FOUNDATION_ROLE, _owner);
        deYieldAddressesProvider = _deYieldAddressesProvider;
        PRECISION = 10000;
        reserveFactor = 1000;
        vaultFee = 50;
        foundationFee = 50;
        pendingExecutionTime = 1 days;
    }

    function deposit(address _token, uint256 _amount) external override {
        require(
            whitelistedAssets.contains(_token),
            "DeYieldVault: asset not whitelisted"
        );

        IXUSD xusd = IXUSD(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getXUSD()
        );
        uint256 amountXUSD = _getAmountXUSDOut(_token, _amount);
        require(amountXUSD > MINIMUM_AMOUNT, "DeYieldVault: amount too low");
        IERC20Metadata(_token).transferFrom(msg.sender, address(this), _amount);
        IXUSD(xusd).mint(address(this), amountXUSD);
        IYEET yeet = IYEET(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getYEET()
        );
        IXUSD(xusd).approve(address(yeet), amountXUSD);
        uint256 amountYeet = yeet.mint(amountXUSD);
        yeet.transfer(msg.sender, amountYeet);
        assets[_token].totalDeposited += _amount;
        emit Deposited(msg.sender, _token, _amount, amountYeet);
    }

    function createRedeemRequest(
        address _assetOut,
        uint256 _amountIn
    ) external override {
        require(_amountIn > 0, "DeYieldVault: amount must be greater than 0");
        require(
            whitelistedAssets.contains(_assetOut),
            "DeYieldVault: asset not whitelisted"
        );
        uint256 pendingOut = estimateAmountRedeem(
            _assetOut,
            _amountIn + assets[_assetOut].totalYEETPendingRedeem
        );
        require(
            pendingOut <= assets[_assetOut].totalDeposited,
            "DeYieldVault: not enough asset to redeem"
        );
        IYEET yeet = IYEET(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getYEET()
        );
        yeet.transferFrom(msg.sender, address(this), _amountIn);
        RedeemRequest memory redeemRequest = RedeemRequest({
            redeemRequestId: redeemRequests.length,
            user: msg.sender,
            assetOut: _assetOut,
            amountIn: _amountIn,
            createAt: block.timestamp,
            executed: false
        });
        redeemRequests.push(redeemRequest);
        pendingRedeemRequests[msg.sender].add(redeemRequests.length - 1);
        assets[_assetOut].totalYEETPendingRedeem += _amountIn;
        emit RedeemRequestCreated(
            msg.sender,
            redeemRequests.length - 1,
            _assetOut,
            _amountIn
        );
    }

    function cancelRedeemRequest(uint256 _redeemRequestId) external override {
        require(
            pendingRedeemRequests[msg.sender].contains(_redeemRequestId),
            "DeYieldVault: redeem request not found"
        );
        IYEET yeet = IYEET(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getYEET()
        );
        RedeemRequest memory redeemRequest = redeemRequests[_redeemRequestId];
        require(
            redeemRequest.executed == false,
            "DeYieldVault: redeem request already executed"
        );

        pendingRedeemRequests[msg.sender].remove(_redeemRequestId);
        assets[redeemRequest.assetOut].totalYEETPendingRedeem -= redeemRequest
            .amountIn;

        yeet.transfer(msg.sender, redeemRequest.amountIn);
        emit RedeemRequestCanceled(
            msg.sender,
            _redeemRequestId,
            redeemRequest.assetOut,
            redeemRequest.amountIn
        );
        delete redeemRequests[_redeemRequestId];
    }

    function executeRedeemRequest(uint256 _redeemRequestId) external override {
        require(
            pendingRedeemRequests[msg.sender].contains(_redeemRequestId),
            "DeYieldVault: redeem request not found"
        );

        RedeemRequest memory redeemRequest = redeemRequests[_redeemRequestId];
        require(
            redeemRequest.executed == false,
            "DeYieldVault: redeem request already executed"
        );

        require(
            block.timestamp - redeemRequest.createAt >= pendingExecutionTime,
            "DeYieldVault: redeem request not ready for execution"
        );

        pendingRedeemRequests[msg.sender].remove(_redeemRequestId);
        executedRedeemRequests[msg.sender].add(_redeemRequestId);
        redeemRequests[_redeemRequestId].executed = true;
        assets[redeemRequest.assetOut].totalYEETPendingRedeem -= redeemRequest
            .amountIn;
        IYEET yeet = IYEET(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getYEET()
        );
        uint256 amountXUSD = yeet.redeem(redeemRequest.amountIn);

        IXUSD xusd = IXUSD(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getXUSD()
        );
        uint256 amountXUSDToFoundation = (amountXUSD * foundationFee) /
            PRECISION;
        xusd.transfer(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getFoundation(),
            amountXUSDToFoundation
        );
        uint256 amountXUSDToVault = (amountXUSD * vaultFee) / PRECISION;
        xusd.approve(address(yeet), amountXUSDToVault);
        yeet.deposit(amountXUSDToVault);
        amountXUSD = amountXUSD - amountXUSDToFoundation - amountXUSDToVault;
        uint256 amountAssetOut = _getAmountRedeemOut(
            redeemRequest.assetOut,
            amountXUSD
        );
        xusd.redeem(amountXUSD);
        IERC20Metadata(redeemRequest.assetOut).transfer(
            msg.sender,
            amountAssetOut
        );
        assets[redeemRequest.assetOut].totalDeposited -= amountAssetOut;
        emit RedeemRequestExecuted(
            msg.sender,
            _redeemRequestId,
            redeemRequest.assetOut,
            redeemRequest.amountIn,
            amountAssetOut
        );
    }

    function foundationWithdrawForInvest(
        address _token,
        uint256 _amount
    ) external override onlyRole(FOUNDATION_ROLE) {
        require(
            whitelistedAssets.contains(_token),
            "DeYieldVault: asset not whitelisted"
        );
        require(
            assets[_token].totalAmountInvested + _amount <
                (assets[_token].totalDeposited * reserveFactor) / PRECISION,
            "DeYieldVault: reserve factor exceeded"
        );
        IERC20Metadata(_token).transfer(msg.sender, _amount);
        assets[_token].totalAmountInvested += _amount;
        emit FoundationWithdrawForInvest(_token, _amount);
    }

    function foundationPayback(
        address _token,
        uint256 _amount
    ) external override onlyRole(FOUNDATION_ROLE) {
        require(
            whitelistedAssets.contains(_token),
            "DeYieldVault: asset not whitelisted"
        );
        require(
            assets[_token].totalAmountInvested >= _amount,
            "DeYieldVault: payback amount exceeds invested amount"
        );
        IERC20Metadata(_token).transferFrom(msg.sender, address(this), _amount);
        assets[_token].totalAmountInvested -= _amount;
        emit FoundationPayback(_token, _amount);
    }

    function foundationDeposit(
        address _token,
        uint256 _amount
    ) external override onlyRole(FOUNDATION_ROLE) {
        require(
            whitelistedAssets.contains(_token),
            "DeYieldVault: asset not whitelisted"
        );
        IERC20Metadata(_token).transferFrom(msg.sender, address(this), _amount);
        assets[_token].totalAmountInvested += _amount;
        emit FoundationDeposited(_token, _amount);
    }

    function increaseXUSDSupply(uint256 _amount) external override {
        IXUSD xusd = IXUSD(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getXUSD()
        );
        xusd.mint(address(this), _amount);
        emit IncreaseXUSDSupply(_amount);
    }

    function setWhitelistedAsset(
        address _asset,
        bool _isSet
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_isSet) {
            require(
                whitelistedAssets.add(_asset),
                "DeYieldVault: asset exists"
            );
            assets[_asset].token = _asset;
            emit AssetWhitelisted(_asset);
        } else {
            require(
                assets[_asset].totalDeposited == 0,
                "DeYieldVault: asset has deposits"
            );
            require(
                whitelistedAssets.remove(_asset),
                "DeYieldVault: asset not whitelisted"
            );
            emit AssetUnwhitelisted(_asset);
        }
    }

    function isWhitelistedAsset(address _asset) external view returns (bool) {
        return whitelistedAssets.contains(_asset);
    }

    function _getAmountRedeemOut(
        address _token,
        uint256 _amountXUSD
    ) internal view returns (uint256) {
        IDeYieldOracle oracle = IDeYieldOracle(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getOracle()
        );
        IDeYieldOracle.PriceResult memory priceResult = oracle.getPrice(_token);

        uint256 tokenDecimals = IERC20Metadata(_token).decimals();
        return
            (_amountXUSD *
                10 ** priceResult.priceDecimals *
                10 ** tokenDecimals) /
            priceResult.price /
            10 ** 18;
    }

    function _getAmountXUSDOut(
        address _asset,
        uint256 _amountIn
    ) internal view returns (uint256) {
        IDeYieldOracle oracle = IDeYieldOracle(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getOracle()
        );
        IDeYieldOracle.PriceResult memory priceResult = oracle.getPrice(_asset);

        uint256 assetDecimals = IERC20Metadata(_asset).decimals();
        return
            (_amountIn * priceResult.price * 10 ** 18) /
            (10 ** assetDecimals) /
            10 ** priceResult.priceDecimals;
    }

    function getAmountOut(
        address _asset,
        uint256 _amountIn
    ) external view returns (uint256) {
        uint256 xusdAmount = _getAmountXUSDOut(_asset, _amountIn);
        IYEET yeet = IYEET(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getYEET()
        );
        return yeet.getAmountOut(xusdAmount);
    }

    function _getAmountAssetIn(
        address _asset,
        uint256 _amountOut
    ) internal view returns (uint256) {
        IDeYieldOracle oracle = IDeYieldOracle(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getOracle()
        );
        IDeYieldOracle.PriceResult memory priceResult = oracle.getPrice(_asset);

        uint256 assetDecimals = IERC20Metadata(_asset).decimals();
        return
            (_amountOut *
                (10 ** assetDecimals) *
                10 ** priceResult.priceDecimals) /
            priceResult.price /
            10 ** 18;
    }

    function getAmountIn(
        address _asset,
        uint256 _amountOut
    ) external view returns (uint256) {
        IYEET yeet = IYEET(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getYEET()
        );
        uint256 xusdAmount = yeet.getAmountIn(_amountOut);
        return _getAmountAssetIn(_asset, xusdAmount);
    }

    function estimateAmountRedeem(
        address _asset,
        uint256 _amountYeet
    ) public view override returns (uint256) {
        require(
            whitelistedAssets.contains(_asset),
            "DeYieldVault: asset not whitelisted"
        );
        IYEET yeet = IYEET(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getYEET()
        );
        uint256 yeetPrice = yeet.getPrice();
        uint256 xusdAmount = (_amountYeet * yeetPrice) / 10 ** 8;
        return _getAmountRedeemOut(_asset, xusdAmount);
    }

    function getWhitelistedAssets() external view returns (address[] memory) {
        address[] memory _assets = new address[](whitelistedAssets.length());
        for (uint256 i = 0; i < whitelistedAssets.length(); i++) {
            _assets[i] = whitelistedAssets.at(i);
        }
        return _assets;
    }

    function getPendingRedeemRequests(
        address _user,
        uint256 _offset,
        uint256 _limit
    ) external view override returns (RedeemRequest[] memory) {
        uint256 length = pendingRedeemRequests[_user].length();
        if (_offset >= length) {
            return new RedeemRequest[](0);
        }
        uint256 end = _offset + _limit > length ? length : _offset + _limit;
        RedeemRequest[] memory requests = new RedeemRequest[](end - _offset);
        for (uint256 i = _offset; i < end; i++) {
            requests[i - _offset] = redeemRequests[
                pendingRedeemRequests[_user].at(i)
            ];
        }
        return requests;
    }

    function getPendingRedeemRequestsLength(
        address _user
    ) external view override returns (uint256) {
        return pendingRedeemRequests[_user].length();
    }

    function getExcutedRedeemRequests(
        address _user,
        uint256 _offset,
        uint256 _limit
    ) external view override returns (RedeemRequest[] memory) {
        uint256 length = executedRedeemRequests[_user].length();
        if (_offset >= length) {
            return new RedeemRequest[](0);
        }
        uint256 end = _offset + _limit > length ? length : _offset + _limit;
        RedeemRequest[] memory requests = new RedeemRequest[](end - _offset);
        for (uint256 i = _offset; i < end; i++) {
            requests[i - _offset] = redeemRequests[
                executedRedeemRequests[_user].at(i)
            ];
        }
        return requests;
    }

    function getExcutedRedeemRequestsLength(
        address _user
    ) external view override returns (uint256) {
        return executedRedeemRequests[_user].length();
    }

    function getAssetsInfo()
        external
        view
        override
        returns (AssetInfo[] memory)
    {
        AssetInfo[] memory _assets = new AssetInfo[](
            whitelistedAssets.length()
        );
        for (uint256 i = 0; i < whitelistedAssets.length(); i++) {
            _assets[i] = assets[whitelistedAssets.at(i)];
        }
        return _assets;
    }

    function setPendingExecutionTime(
        uint256 _time
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        pendingExecutionTime = _time;
        emit PendingExecutionTimeSet(_time);
    }

    function setReserveFactor(
        uint256 _reserveFactor
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        reserveFactor = _reserveFactor;
        emit ReserveFactorSet(_reserveFactor);
    }

    function setFee(
        uint256 _vaultFee,
        uint256 _foundationFee
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _vaultFee + _foundationFee < 1000,
            "DeYieldVault: fee exceeds 100%"
        );
        vaultFee = _vaultFee;
        foundationFee = _foundationFee;
        emit FeeSet(_vaultFee, _foundationFee);
    }

    function emergencyWithdraw(
        address _token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20Metadata(_token).transfer(
            msg.sender,
            IERC20Metadata(_token).balanceOf(address(this))
        );
    }
}
