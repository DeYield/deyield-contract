// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "../interfaces/IDeYieldAddressesProvider.sol";
import "../libs/Constants.sol";
import "../interfaces/IXUSD.sol";

contract XUSDCoin is ERC20, ERC20Permit, IXUSD {
    address public deYieldAddressesProvider;
    mapping(address => bool) public whitelistTransfer;

    modifier onlyDeYieldVault() {
        require(
            msg.sender ==
                IDeYieldAddressesProvider(deYieldAddressesProvider).getContract(
                    Constants.DEYIELD_VAULT
                ),
            "XUSDCoin: Caller is not the DeYieldVault"
        );
        _;
    }
    modifier onlyWhitelistTransfer(address _from, address _to) {
        address deYieldVault = IDeYieldAddressesProvider(
            deYieldAddressesProvider
        ).getContract(Constants.DEYIELD_VAULT);
        require(
            whitelistTransfer[_from] ||
                whitelistTransfer[_to] ||
                _from == deYieldVault ||
                _to == deYieldVault,
            "XUSDCoin: Caller is not the whitelisted address"
        );
        _;
    }
    constructor(
        address _deYieldAddressesProvider
    ) ERC20("xUSD Coin", "XUSD") ERC20Permit("xUSD Coin") {
        deYieldAddressesProvider = _deYieldAddressesProvider;
    }

    function mint(address to, uint256 amount) public onlyDeYieldVault {
        _mint(to, amount);
    }

    function redeem(uint256 amount) public onlyDeYieldVault {
        _burn(msg.sender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override onlyWhitelistTransfer(from, to) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
