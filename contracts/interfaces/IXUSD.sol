// SPDX: License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IXUSD is IERC20 {
    function mint(address to, uint256 amount) external;
    function redeem(uint256 amount) external;
}
