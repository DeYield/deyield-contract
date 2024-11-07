// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Faucet is Pausable, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private tokens;
    uint256 public faucetPeriod = 1 days;
    mapping(address => uint256) public tokenAmount;
    mapping(address => uint256) public lastFaucetTime;

    modifier notContract() {
        require(tx.origin == msg.sender, "Faucet: Caller is a contract");
        _;
    }

    constructor(address[] memory _tokens, uint256[] memory _tokenAmounts) {
        require(
            _tokens.length == _tokenAmounts.length,
            "Faucet: Invalid input"
        );
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(tokens.add(_tokens[i]), "Faucet: Duplicate token");
            tokenAmount[_tokens[i]] = _tokenAmounts[i];
        }
    }

    function faucet() public notContract whenNotPaused {
        require(
            block.timestamp - lastFaucetTime[msg.sender] >= faucetPeriod,
            "Faucet: Faucet period not passed"
        );
        lastFaucetTime[msg.sender] = block.timestamp;
        for (uint256 i = 0; i < tokens.length(); i++) {
            address token = tokens.at(i);
            IERC20(token).transfer(msg.sender, tokenAmount[token]);
        }
    }

    function addToken(address _token, uint256 _tokenAmount) public onlyOwner {
        require(tokens.add(_token), "Faucet: Duplicate token");
        tokenAmount[_token] = _tokenAmount;
    }

    function removeToken(address _token) public onlyOwner {
        require(tokens.remove(_token), "Faucet: Token not found");
        delete tokenAmount[_token];
    }

    function setTokenAmount(
        address _token,
        uint256 _tokenAmount
    ) public onlyOwner {
        require(tokens.contains(_token), "Faucet: Token not found");
        tokenAmount[_token] = _tokenAmount;
    }

    function setFaucetPeriod(uint256 _faucetPeriod) public onlyOwner {
        faucetPeriod = _faucetPeriod;
    }

    function getTokens() public view returns (address[] memory) {
        return tokens.values();
    }

    function emergencyWithdraw() public onlyOwner {
        for (uint256 i = 0; i < tokens.length(); i++) {
            address token = tokens.at(i);
            IERC20(token).transfer(
                owner(),
                IERC20(token).balanceOf(address(this))
            );
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
