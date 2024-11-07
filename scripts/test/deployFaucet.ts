import { ethers, run } from "hardhat";
import { deployContract, save, readDeployment, sendTxn } from "../helper";
import { Faucet } from "../../typechain-types";

async function main() {
  const usdtAddress = readDeployment("usdt");
  const usdcAddress = readDeployment("usdc");
  const daiAddress = readDeployment("dai");

  const usdt = await ethers.getContractAt("TestERC20", usdtAddress);
  const usdc = await ethers.getContractAt("TestERC20", usdcAddress);
  const dai = await ethers.getContractAt("TestERC20", daiAddress);

  const faucet = await deployContract<Faucet>("Faucet", [
    [daiAddress, usdcAddress, usdtAddress],
    [
      ethers.parseUnits("10", 18).toString(),
      ethers.parseUnits("10", 6).toString(),
      ethers.parseUnits("10", 6).toString(),
    ],
  ]);
  save("faucet", await faucet.getAddress());
  await sendTxn(
    usdt.mint(await faucet.getAddress(), ethers.parseUnits("1000000", 6)),
    "usdt.mint"
  );
  await sendTxn(
    usdc.mint(await faucet.getAddress(), ethers.parseUnits("1000000", 6)),
    "usdc.mint"
  );

  await sendTxn(
    dai.mint(await faucet.getAddress(), ethers.parseUnits("1000000", 18)),
    "dai.mint"
  );
  await new Promise((resolve) => setTimeout(resolve, 10000));

  await run("verify:verify", {
    address: await faucet.getAddress(),
    constructorArguments: [
      [daiAddress, usdcAddress, usdtAddress],
      [
        ethers.parseUnits("10", 18).toString(),
        ethers.parseUnits("10", 6).toString(),
        ethers.parseUnits("10", 6).toString(),
      ],
    ],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
