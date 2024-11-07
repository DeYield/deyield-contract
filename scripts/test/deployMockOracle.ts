import { ethers } from "hardhat";
import { deployContract, save } from "../helper";
import { MockOracle } from "../../typechain-types";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  const mockOracle = await deployContract<MockOracle>("MockOracle", []);
  save("bandOracle", await mockOracle.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
