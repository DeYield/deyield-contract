import { ethers } from "hardhat";
import {
  DeYieldAddressesProvider,
  DeYieldOracle,
  DeYieldVault,
  MockOracle,
  TestERC20,
  XUSDCoin,
  YEETToken,
} from "../typechain-types";
import { Signer } from "ethers";
import { expect } from "chai";
import { bigint } from "hardhat/internal/core/params/argumentTypes";
import exp from "constants";

const defaultPrice = "99950000";
describe("DeYield", function () {
  let dai: TestERC20, usdc: TestERC20, usdt: TestERC20;
  let xusd: XUSDCoin,
    yeet: YEETToken,
    stdOracle: MockOracle,
    oracle: DeYieldOracle,
    vault: DeYieldVault,
    addressesProvider: DeYieldAddressesProvider;
  let deployer: Signer, user1: Signer, user2: Signer;

  before(async function () {
    [deployer, user1, user2] = await ethers.getSigners();
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    dai = (await TestERC20.deploy("DAI", "DAI", 18)) as TestERC20;
    usdc = (await TestERC20.deploy("USDC", "USDC", 6)) as TestERC20;
    usdt = (await TestERC20.deploy("USDT", "USDT", 6)) as TestERC20;
    addressesProvider = await ethers.deployContract(
      "DeYieldAddressesProvider",
      []
    );
    stdOracle = await ethers.deployContract("MockOracle", []);
    oracle = await ethers.deployContract("DeYieldOracle", [
      await stdOracle.getAddress(),
    ]);
    await oracle.registerAssets(
      [
        await dai.getAddress(),
        await usdc.getAddress(),
        await usdt.getAddress(),
      ],
      ["DAI", "USDC", "USDT"],
      [8, 8, 8]
    );
    xusd = await ethers.deployContract("XUSDCoin", [
      await addressesProvider.getAddress(),
    ]);
    yeet = await ethers.deployContract("YEETToken", [
      await addressesProvider.getAddress(),
    ]);
    const vaultImpl = await ethers.deployContract("DeYieldVault", []);
    const initData = vaultImpl.interface.encodeFunctionData("initialize", [
      await addressesProvider.getAddress(),
      await deployer.getAddress(),
    ]);
    await addressesProvider.setContractProxy(
      "DEYIELD_VAULT",
      await vaultImpl.getAddress(),
      initData
    );
    vault = await ethers.getContractAt(
      "DeYieldVault",
      await addressesProvider.getContract("DEYIELD_VAULT")
    );
    await addressesProvider.setContract("YEET", await yeet.getAddress());
    await addressesProvider.setContract("XUSD", await xusd.getAddress());
    await addressesProvider.setContract("ORACLE", await oracle.getAddress());
    await addressesProvider.setContract(
      "FOUNDATION",
      await deployer.getAddress()
    );

    await vault.setWhitelistedAsset(await dai.getAddress(), true);
    await vault.setWhitelistedAsset(await usdc.getAddress(), true);
    await vault.setWhitelistedAsset(await usdt.getAddress(), true);

    await dai.transfer(
      await user1.getAddress(),
      ethers.parseUnits("100000", 18)
    );
    await usdc.transfer(
      await user1.getAddress(),
      ethers.parseUnits("100000", 6)
    );
    await usdt.transfer(
      await user1.getAddress(),
      ethers.parseUnits("100000", 6)
    );

    await dai.transfer(
      await user2.getAddress(),
      ethers.parseUnits("100000", 18)
    );
    await usdc.transfer(
      await user2.getAddress(),
      ethers.parseUnits("100000", 6)
    );
    await usdt.transfer(
      await user2.getAddress(),
      ethers.parseUnits("100000", 6)
    );

    await dai
      .connect(user1)
      .approve(await vault.getAddress(), ethers.MaxUint256);
    await usdc
      .connect(user1)
      .approve(await vault.getAddress(), ethers.MaxUint256);
    await usdt
      .connect(user1)
      .approve(await vault.getAddress(), ethers.MaxUint256);
    await dai
      .connect(user2)
      .approve(await vault.getAddress(), ethers.MaxUint256);
    await usdc
      .connect(user2)
      .approve(await vault.getAddress(), ethers.MaxUint256);
    await usdt
      .connect(user2)
      .approve(await vault.getAddress(), ethers.MaxUint256);

    await yeet
      .connect(user1)
      .approve(await vault.getAddress(), ethers.MaxUint256);
    await yeet
      .connect(user2)
      .approve(await vault.getAddress(), ethers.MaxUint256);
  });

  it("should deploy successfully", async function () {
    expect(await dai.getAddress()).to.be.properAddress;
    expect(await usdc.getAddress()).to.be.properAddress;
    expect(await usdt.getAddress()).to.be.properAddress;
    expect(await addressesProvider.getAddress()).to.be.properAddress;
    expect(await stdOracle.getAddress()).to.be.properAddress;
    expect(await oracle.getAddress()).to.be.properAddress;
    expect(await xusd.getAddress()).to.be.properAddress;
    expect(await yeet.getAddress()).to.be.properAddress;
    expect(await vault.getAddress()).to.be.properAddress;
  });

  it("should mint yeet successfully", async function () {
    await expect(
      vault
        .connect(user1)
        .deposit(await dai.getAddress(), ethers.parseUnits("1", 18))
    ).to.be.revertedWith("DeYieldVault: amount too low");

    await vault
      .connect(user1)
      .deposit(await usdt.getAddress(), ethers.parseUnits("1000", 6));

    expect(await yeet.balanceOf(await user1.getAddress())).to.be.eq(
      (ethers.parseUnits("1000", 18) * BigInt(defaultPrice)) / BigInt(1e8)
    );

    await vault
      .connect(user2)
      .deposit(await dai.getAddress(), ethers.parseUnits("10000", 18));
    expect(await yeet.balanceOf(await user2.getAddress())).to.be.eq(
      (ethers.parseUnits("10000", 18) * BigInt(defaultPrice)) / BigInt(1e8)
    );
  });

  it("should deposit and redeem successfully", async function () {
    await vault
      .connect(user1)
      .createRedeemRequest(
        await usdt.getAddress(),
        ethers.parseUnits("100", 6)
      );
    const yeetBalanceBefore = await yeet.balanceOf(await user2.getAddress());
    await vault
      .connect(user2)
      .createRedeemRequest(
        await usdt.getAddress(),
        ethers.parseUnits("100", 18)
      );
    const yeetBalanceAfter = await yeet.balanceOf(await user2.getAddress());
    expect(yeetBalanceBefore).to.be.gt(yeetBalanceAfter);

    await expect(
      vault
        .connect(user2)
        .createRedeemRequest(
          await usdt.getAddress(),
          ethers.parseUnits("1000", 18)
        )
    ).to.be.revertedWith("DeYieldVault: not enough asset to redeem");

    await vault.connect(user2).cancelRedeemRequest(1);
    expect(await yeet.balanceOf(await user2.getAddress())).to.be.eq(
      yeetBalanceBefore
    );
    await expect(
      vault.connect(user2).cancelRedeemRequest(1)
    ).to.be.revertedWith("DeYieldVault: redeem request not found");
    await vault
      .connect(user2)
      .createRedeemRequest(
        await usdt.getAddress(),
        ethers.parseUnits("100", 18)
      );
    await expect(
      vault.connect(user2).executeRedeemRequest(2)
    ).to.be.revertedWith(
      "DeYieldVault: redeem request not ready for execution"
    );

    await increaseTime(86400);

    const usdtBalanceBefore = await usdt.balanceOf(await user2.getAddress());
    await vault.connect(user2).executeRedeemRequest(2);
    const usdtBalanceAfter = await usdt.balanceOf(await user2.getAddress());
    expect(usdtBalanceAfter).to.be.gt(usdtBalanceBefore);
  });
});

async function increaseTime(seconds: number) {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
}
