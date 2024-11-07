// SPDX: License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDeYieldOracle.sol";
import "../interfaces/IStdReference.sol";
import "../interfaces/ISupraOraclePull.sol";
import "../libs/Errors.sol";

contract MockOracle is IStdReference, Ownable {
    constructor() {}

    function getReferenceData(
        string memory _base,
        string memory _quote
    ) external view override returns (ReferenceData memory) {
        return
            ReferenceData({
                rate: (9995 * 10 ** 18) / 10 ** 4,
                lastUpdatedBase: block.timestamp,
                lastUpdatedQuote: block.timestamp
            });
    }

    function getReferenceDataBulk(
        string[] memory _bases,
        string[] memory _quotes
    ) external view override returns (ReferenceData[] memory) {
        ReferenceData[] memory data = new ReferenceData[](_bases.length);
        for (uint256 i = 0; i < _bases.length; i++) {
            data[i] = ReferenceData({
                rate: 10 ** 18,
                lastUpdatedBase: block.timestamp,
                lastUpdatedQuote: block.timestamp
            });
        }
        return data;
    }
}
