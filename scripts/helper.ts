import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import * as fs from "fs";

async function deployContract<T>(
  name: string,
  args: any[],
  label?: any,
  options?: any
) {
  if (!options && typeof label === "object") {
    label = null;
    options = label;
  }

  let info = name;
  if (label) {
    info = name + ":" + label;
  }
  let contract: Contract;
  if (!options) {
    contract = await ethers.deployContract(name, args);
  } else {
    contract = await ethers.deployContract(name, args, options);
  }
  console.log(args.toString());
  const argStr = args.map((i) => `"${i}"`).join(" ");
  console.info(`Deploying ${info} ${await contract.getAddress()} ${argStr}`);
  await contract.waitForDeployment();
  console.info("... Completed!");
  writeDeployedContract(name, await contract.getAddress(), args);
  return contract as T;
}

async function deployContractWithArtifact(
  artifact: any,
  args: any[],
  label: any,
  options: any
) {
  if (!options && typeof label === "object") {
    label = null;
    options = label;
  }

  let info = artifact.contractName;
  if (label) {
    info = artifact.contractName + ":" + label;
  }
  const contractFactory = new ContractFactory(
    artifact.abi,
    artifact.bytecode,
    await ethers.provider.getSigner()
  );

  let contract = await contractFactory.deploy(...args);
  const argStr = args.map((i) => `"${i}"`).join(" ");
  console.info(`Deploying ${info} ${await contract.getAddress()} ${argStr}`);
  await contract.waitForDeployment();
  console.info("... Completed!");
  return contract;
}

async function sendTxn(txnPromise: Promise<any>, label: string) {
  console.info(`Processing ${label}:`);
  const txn = await txnPromise;
  console.info(`Sending ${label}...`);
  await txn.wait(1);
  console.info(`... Sent! ${txn.hash}`);
  return txn;
}

function writeDeployedContract(name: string, contract: string, args: any[]) {
  const network = process.env.HARDHAT_NETWORK || "hardhat";
  const filePath = `./deployed/${network}-deployments.json`;
  if (!fs.existsSync("./deployed")) {
    fs.mkdirSync("./deployed");
  }
  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(
      filePath,
      JSON.stringify(
        { [contract]: { contract: contract, args: args } },
        null,
        2
      )
    );
  } else {
    const file = fs.readFileSync(filePath);
    const json = JSON.parse(file.toString());
    json[contract] = { name: name, contract: contract, args: args };
    fs.writeFileSync(filePath, JSON.stringify(json, null, 2));
  }
}

function save(name: string, address: string) {
  saveDeployment(new Map([[name, address]]));
}

function saveDeployment(data: Map<string, string>) {
  const network = process.env.HARDHAT_NETWORK || "hardhat";
  const filePath = `./deployed/${network}-addresses.json`;
  if (!fs.existsSync("./deployed")) {
    fs.mkdirSync("./deployed");
  }
  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  }
  const file = fs.readFileSync(filePath);
  const json = JSON.parse(file.toString());
  for (let key of data.keys()) {
    json[key] = data.get(key);
  }
  fs.writeFileSync(filePath, JSON.stringify(json, null, 2));
}

function readDeployment(contract: string): string {
  const network = process.env.HARDHAT_NETWORK || "hardhat";
  const filePath = `./deployed/${network}-addresses.json`;
  if (!fs.existsSync(filePath)) {
    return "";
  }
  const file = fs.readFileSync(filePath);
  const json = JSON.parse(file.toString());
  return json[contract] || "";
}
export {
  readDeployment,
  saveDeployment,
  deployContract,
  sendTxn,
  deployContractWithArtifact,
  save,
};
