import { ethers } from "hardhat";
import { deployContract, saveDeployment, sendTxn } from "../helper";
import { TestERC20 } from "../../typechain-types";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  const usdt = await deployContract<TestERC20>("TestERC20", [
    "USDT",
    "USDT",
    6,
  ]);
  const usdc = await deployContract<TestERC20>("TestERC20", [
    "USDC",
    "USDC",
    6,
  ]);

  const dai = await deployContract<TestERC20>("TestERC20", ["DAI", "DAI", 18]);

  saveDeployment(
    new Map([
      ["usdt", await usdt.getAddress()],
      ["usdc", await usdc.getAddress()],
      ["dai", await dai.getAddress()],
    ])
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
