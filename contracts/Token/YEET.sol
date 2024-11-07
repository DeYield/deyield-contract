// SPDX: License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IDeYieldAddressesProvider.sol";
import "../interfaces/IYEET.sol";
import "../interfaces/IXUSD.sol";

contract YEETToken is ERC20, ERC20Burnable, ERC20Permit, AccessControl, IYEET {
    address public deYieldAddressesProvider;
    uint256 public blockTimestampLast;

    event YEETMinted(
        address indexed user,
        uint256 amountXUSD,
        uint256 amountYEET
    );

    event YEETRedeemed(
        address indexed user,
        uint256 amountXUSD,
        uint256 amountYEET
    );

    event XUSDDeposited(address indexed user, uint256 amount);

    modifier onlyDeYieldVault() {
        require(
            msg.sender ==
                IDeYieldAddressesProvider(deYieldAddressesProvider).getVault(),
            "YEETToken: Caller is not the DeYieldVault"
        );
        _;
    }

    constructor(
        address _deYieldAddressesProvider
    ) ERC20("YEET Token", "YEET") ERC20Permit("YEET Token") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        deYieldAddressesProvider = _deYieldAddressesProvider;
    }

    function mint(
        uint256 amount
    ) external override onlyDeYieldVault returns (uint256) {
        (uint256 xusdReserve, uint256 yeetReserve, ) = getReserves();
        uint256 amountYEET = amount;
        if (xusdReserve != 0) {
            amountYEET = (amount * yeetReserve) / xusdReserve;
        }
        IXUSD xusd = IXUSD(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getXUSD()
        );
        xusd.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amountYEET);

        blockTimestampLast = block.timestamp;
        emit YEETMinted(msg.sender, amount, amountYEET);
        return amountYEET;
    }

    function redeem(uint256 amount) external override returns (uint256) {
        (uint256 xusdReserve, uint256 yeetReserve, ) = getReserves();
        uint256 amountXUSD = amount;
        if (xusdReserve != 0) {
            amountXUSD = (amount * xusdReserve) / yeetReserve;
        }
        _burn(msg.sender, amount);
        IXUSD xusd = IXUSD(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getXUSD()
        );
        xusd.transfer(msg.sender, amountXUSD);
        blockTimestampLast = block.timestamp;
        emit YEETRedeemed(msg.sender, amountXUSD, amount);
        return amountXUSD;
    }

    function deposit(uint256 amount) public {
        IXUSD xusd = IXUSD(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getXUSD()
        );
        xusd.transferFrom(msg.sender, address(this), amount);
        emit XUSDDeposited(msg.sender, amount);
    }

    function getReserves()
        public
        view
        returns (
            uint256 xusdReserve,
            uint256 yeetReserve,
            uint256 _blockTimestampLast
        )
    {
        IXUSD xusd = IXUSD(
            IDeYieldAddressesProvider(deYieldAddressesProvider).getXUSD()
        );
        xusdReserve = xusd.balanceOf(address(this));
        yeetReserve = totalSupply();
        _blockTimestampLast = blockTimestampLast;
    }

    function getAmountOut(
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut, ) = getReserves();
        require(amountIn > 0, "YEETTken: Insufficient input amount");
        if (reserveIn == 0 || reserveOut == 0) {
            amountOut = amountIn;
        } else {
            amountOut = (amountIn * reserveOut) / reserveIn;
        }
    }

    function getAmountIn(uint256 amountOut) external view returns (uint256) {
        (uint256 reserveIn, uint256 reserveOut, ) = getReserves();
        require(amountOut > 0, "YEETToken: Insufficient output amount");
        require(
            reserveIn > 0 && reserveOut > 0,
            "YEETToken: Insufficient reserves"
        );
        return (amountOut * reserveIn) / reserveOut;
    }

    function getPrice() public view returns (uint256 price) {
        (uint256 xusdReserve, uint256 yeetReserve, ) = getReserves();
        price = (xusdReserve * 1e8) / yeetReserve;
    }
}
