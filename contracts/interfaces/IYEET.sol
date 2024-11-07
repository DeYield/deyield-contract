// SPDX: License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IYEET is IERC20 {
    function mint(uint256 amount) external returns (uint256);
    function redeem(uint256 amount) external returns (uint256);
    function deposit(uint256 amount) external;
    function getReserves()
        external
        view
        returns (
            uint256 xusdReserve,
            uint256 yeetReserve,
            uint256 _blockTimestampLast
        );
    function getPrice() external view returns (uint256);
    function getAmountOut(uint256 amountIn) external view returns (uint256);
    function getAmountIn(uint256 amountOut) external view returns (uint256);
}
