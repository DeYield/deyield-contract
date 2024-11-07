// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC20 is ERC20, Ownable {
    mapping(address => bool) public minters;
    uint8 _decimals;

    modifier onlyMinter() {
        require(minters[msg.sender], "Only minter can call this function");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 decimals_
    ) ERC20(_name, _symbol) {
        _decimals = decimals_;
        _mint(msg.sender, 1000000 * 10 ** decimals());
        minters[msg.sender] = true;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public onlyMinter {
        _mint(to, amount);
    }

    function setMinter(address minter, bool canMint) public onlyOwner {
        minters[minter] = canMint;
    }
}
