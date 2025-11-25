const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Pair Contract (with Factory createPair test)", function () {
  let pair, token0, token1, factory, owner;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    // Deploy ERC20 mock tokens
    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    token0 = await ERC20.deploy("Token0", "T0", 18);
    token1 = await ERC20.deploy("Token1", "T1", 18);

    // Deploy Factory (set feeToSetter to owner)
    const Factory = await ethers.getContractFactory("UniswapV2Factory");
    factory = await Factory.deploy(owner.address);
    await factory.deployed();

    // Create pair from factory
    await factory.createPair(token0.address, token1.address);
    const pairAddress = await factory.getPair(token0.address, token1.address);

    const Pair = await ethers.getContractFactory("UniswapV2Pair");
    pair = await Pair.attach(pairAddress);
  });

  it("initializes token addresses", async () => {
    expect(await pair.token0()).to.equal(token0.address);
    expect(await pair.token1()).to.equal(token1.address);
  });



  // 🔥 新增：createPair 测试（替换 burn 测试）
  it("creates pair through factory", async () => {
    const pairAddress = await factory.getPair(token0.address, token1.address);

    expect(pairAddress).to.not.equal(ethers.constants.AddressZero);

    const createdPair = await (await ethers.getContractFactory("UniswapV2Pair")).attach(pairAddress);

    // The pair sorts tokens by address (token0 < token1)
    const expected0 = token0.address.toLowerCase() < token1.address.toLowerCase() ? token0.address : token1.address;
    const expected1 = token0.address.toLowerCase() < token1.address.toLowerCase() ? token1.address : token0.address;
    expect(await createdPair.token0()).to.equal(expected0);
    expect(await createdPair.token1()).to.equal(expected1);

    // pair must be inside allPairs array
    const allPairs0 = await factory.allPairs(0);
    expect(allPairs0).to.equal(pairAddress);
  });

  it("emits PairCreated when creating new pair", async () => {
    // Deploy fresh factory to get new event
    const Factory = await ethers.getContractFactory("UniswapV2Factory");
    const freshFactory = await Factory.deploy(owner.address);
    await freshFactory.deployed();

    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    const t0 = await ERC20.deploy("Token0", "T0", 18);
    const t1 = await ERC20.deploy("Token1", "T1", 18);

    await expect(freshFactory.createPair(t0.address, t1.address)).to.emit(freshFactory, "PairCreated");
  });

  it("reverts when creating pair with identical token addresses", async () => {
    await expect(factory.createPair(token0.address, token0.address)).to.be.revertedWith("UniswapV2: IDENTICAL_ADDRESSES");
  });

  it("reverts when creating pair with zero address", async () => {
    await expect(factory.createPair(token0.address, ethers.constants.AddressZero)).to.be.revertedWith("UniswapV2: ZERO_ADDRESS");
  });

  it("reverts when creating pair twice", async () => {
    // first creation already happened in beforeEach
    await expect(factory.createPair(token0.address, token1.address)).to.be.revertedWith("UniswapV2: PAIR_EXISTS");
  });

  it("setFeeTo can be called only by feeToSetter (owner)", async () => {
    // owner is feeToSetter (from constructor)
    const signers = await ethers.getSigners();
    const nonSetter = signers[1];

    // non-setter cannot set feeTo
    await expect(factory.connect(nonSetter).setFeeTo(nonSetter.address)).to.be.revertedWith("UniswapV2: FORBIDDEN");

    // owner can set feeTo
    await factory.connect(owner).setFeeTo(nonSetter.address);
    expect(await factory.feeTo()).to.equal(nonSetter.address);
  });
});
