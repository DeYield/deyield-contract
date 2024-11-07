// SPDX: License-Identifier: MIT

interface IDeYieldOracle {
    struct Asset {
        string symbol;
        address token;
        uint256 priceDecimals;
    }

    struct PriceResult {
        uint256 price;
        uint256 priceDecimals;
        uint256 lastUpdate;
    }

    event AssetRegistered(address token, string symbol, uint256 priceDecimals);
    event AssetUnregistered(address token);
    event OracleUpdated(address oracle);

    function registerAssets(
        address[] calldata _tokens,
        string[] calldata _symbols,
        uint256[] calldata _decimals
    ) external;

    function unregisterAssets(address[] calldata _tokens) external;
    function updateOracle(address _oracle) external;
    function getPrice(
        address _token
    ) external view returns (PriceResult memory);
}
