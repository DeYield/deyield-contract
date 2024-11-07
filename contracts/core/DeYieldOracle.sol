// SPDX: License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDeYieldOracle.sol";
import "../interfaces/IStdReference.sol";
import "../interfaces/ISupraOraclePull.sol";
import "../libs/Errors.sol";

contract DeYieldOracle is IDeYieldOracle, Ownable {
    uint256 public oraclePriceDecimals = 18;
    address public oracle;
    mapping(address => Asset) public assets;

    constructor(address _oracle) {
        oracle = _oracle;
    }

    function registerAssets(
        address[] calldata _tokens,
        string[] calldata _symbols,
        uint256[] calldata _decimals
    ) external override onlyOwner {
        if (
            _tokens.length != _symbols.length ||
            _tokens.length != _decimals.length
        ) {
            revert Errors.InvalidInputLength();
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            assets[_tokens[i]] = Asset({
                symbol: _symbols[i],
                token: _tokens[i],
                priceDecimals: _decimals[i]
            });
            emit AssetRegistered(_tokens[i], _symbols[i], _decimals[i]);
        }
    }

    function unregisterAssets(
        address[] calldata _tokens
    ) external override onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            delete assets[_tokens[i]];
            emit AssetUnregistered(_tokens[i]);
        }
    }
    function updateOracle(address _oracle) external override onlyOwner {
        oracle = _oracle;
        emit OracleUpdated(_oracle);
    }
    function getPrice(
        address _token
    ) external view returns (PriceResult memory) {
        Asset memory asset = assets[_token];
        if (asset.token == address(0)) {
            revert Errors.AssetNotRegistered(_token);
        }
        IStdReference.ReferenceData memory data = IStdReference(oracle)
            .getReferenceData(asset.symbol, assets[_token].symbol);

        uint256 price = (data.rate * 10 ** asset.priceDecimals) /
            10 ** oraclePriceDecimals;
        return
            PriceResult({
                price: price,
                priceDecimals: asset.priceDecimals,
                lastUpdate: data.lastUpdatedBase
            });
    }
}
