import { ethers } from "hardhat";
import {
  deployContract,
  saveDeployment,
  readDeployment,
  sendTxn,
  save,
} from "./helper";
import {
  DeYieldAddressesProvider,
  DeYieldOracle,
  DeYieldVault,
  XUSDCoin,
  YEETToken,
} from "../typechain-types";
import { send } from "process";

async function main() {
  const usdt = readDeployment("usdt");
  const usdc = readDeployment("usdc");
  const dai = readDeployment("dai");
  const bandOracle = readDeployment("bandOracle");

  if (!usdt || !usdc || !dai) {
    console.error("Please deploy the test tokens first");
    process.exit(1);
  }

  if (!bandOracle) {
    console.error("Please deploy the oracle first");
    process.exit(1);
  }

  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  const deYieldAddressesProvider =
    await deployContract<DeYieldAddressesProvider>(
      "DeYieldAddressesProvider",
      []
    );
  save("addressesProvider", await deYieldAddressesProvider.getAddress());

  const deYieldOracle = await deployContract<DeYieldOracle>("DeYieldOracle", [
    bandOracle,
  ]);
  save("deYieldOracle", await deYieldOracle.getAddress());
  await sendTxn(
    deYieldOracle.registerAssets(
      [usdt, usdc, dai],
      ["USDT", "USDC", "DAI"],
      [8, 8, 8]
    ),
    "register assets oracle"
  );

  const xusd = await deployContract<XUSDCoin>("XUSDCoin", [
    await deYieldAddressesProvider.getAddress(),
  ]);
  save("xusd", await xusd.getAddress());

  const yeet = await deployContract<YEETToken>("YEETToken", [
    await deYieldAddressesProvider.getAddress(),
  ]);
  save("yeet", await yeet.getAddress());
  const vaultImpl = await deployContract<DeYieldVault>("DeYieldVault", []);
  save("vaultImpl", await vaultImpl.getAddress());
  const initData = vaultImpl.interface.encodeFunctionData("initialize", [
    await deYieldAddressesProvider.getAddress(),
    await deployer.getAddress(),
  ]);
  await sendTxn(
    deYieldAddressesProvider.setContractProxy(
      "DEYIELD_VAULT",
      await vaultImpl.getAddress(),
      initData
    ),
    "set contract proxy vault"
  );
  const vault = await ethers.getContractAt(
    "DeYieldVault",
    await deYieldAddressesProvider.getContract("DEYIELD_VAULT")
  );
  save("vault", await vault.getAddress());

  await sendTxn(
    deYieldAddressesProvider.setContract("YEET", await yeet.getAddress()),
    "set contract yeet"
  );
  await sendTxn(
    deYieldAddressesProvider.setContract("XUSD", await xusd.getAddress()),
    "set contract xusd"
  );
  await sendTxn(
    deYieldAddressesProvider.setContract(
      "ORACLE",
      await deYieldOracle.getAddress()
    ),
    "set contract oracle"
  );
  await sendTxn(
    deYieldAddressesProvider.setContract(
      "FOUNDATION",
      await deployer.getAddress()
    ),
    "set contract foundation"
  );

  await sendTxn(vault.setWhitelistedAsset(usdt, true), "whitelist usdt");
  await sendTxn(vault.setWhitelistedAsset(usdc, true), "whitelist usdc");
  await sendTxn(vault.setWhitelistedAsset(dai, true), "whitelist dai");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
