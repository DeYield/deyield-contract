// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeYieldUpgradeableProxy is TransparentUpgradeableProxy {
    constructor()
        payable
        TransparentUpgradeableProxy(msg.sender, msg.sender, new bytes(0))
    {}

    function initialize(address _implementation) public {
        require(msg.sender == _admin(), "DeYieldUpgradeableProxy: admin only");
        _upgradeTo(_implementation);
    }
}
