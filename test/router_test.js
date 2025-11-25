const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AddLiquidity Mint事件一致性集成测试", function () {
  let owner;
  let factory;
  let router;
  let weth;
  let tokenA;
  let tokenB;

  beforeEach(async () => {
    [owner] = await ethers.getSigners();
    const initialSupply = ethers.utils.parseEther("1000000");

    // ----------------------------------------------------
    // 1. 部署 Factory
    // ----------------------------------------------------
    const Factory = await ethers.getContractFactory("UniswapV2Factory");
    factory = await Factory.deploy(owner.address);
    await factory.deployed();

    // ----------------------------------------------------
    // 2. 部署 WETH
    // ----------------------------------------------------
    const WETH = await ethers.getContractFactory("WETH9");
    weth = await WETH.deploy();
    await weth.deployed();

    // ----------------------------------------------------
    // 3. 部署 Router
    // ----------------------------------------------------
    const Router = await ethers.getContractFactory("UniswapV2Router02");
    router = await Router.deploy(factory.address, weth.address);
    await router.deployed();

    // ----------------------------------------------------
    // 4. 部署代币 (根据提供的 Solidity 源码修复)
    // ----------------------------------------------------
    
    // --- 部署 TokenA ---
    // TokenA 构造函数: constructor(string memory name, string memory symbol)
    const TokenAFactory = await ethers.getContractFactory("TokenA");
    tokenA = await TokenAFactory.deploy("Token A", "TKNA");
    await tokenA.deployed();
    // TokenA 需要手动 mint
    await tokenA.mint(owner.address, initialSupply);

    // --- 部署 TokenB ---
    // TokenB 构造函数: constructor()
    const TokenBFactory = await ethers.getContractFactory("TokenB");
    tokenB = await TokenBFactory.deploy();
    await tokenB.deployed();
    // TokenB 构造函数里自带了 _mint(msg.sender, 1000000...), 所以不需要手动 mint
    // 如果需要更多余额，可以调用: await tokenB.mint(owner.address, initialSupply);

    // ----------------------------------------------------
    // 5. 排序代币地址
    // ----------------------------------------------------
    // Uniswap 逻辑要求 token0 < token1。
    // 为了测试方便，我们在这里交换变量，确保 tokenA 始终代表地址较小的那个 (token0)
    if (tokenA.address.toLowerCase() > tokenB.address.toLowerCase()) {
      [tokenA, tokenB] = [tokenB, tokenA];
    }
    
    console.log(`Token0: ${tokenA.address}`);
    console.log(`Token1: ${tokenB.address}`);
  });

  it("Mint事件参数 与 实际 LP 一致", async () => {
    const amountADesired = ethers.utils.parseEther("10");
    const amountBDesired = ethers.utils.parseEther("10");

    // 1. 授权 Router 消费代币
      await tokenA.connect(owner).approve(router.address, amountADesired);
      await tokenB.connect(owner).approve(router.address, amountBDesired);

    // 2. 执行 addLiquidity
    const tx = await router.addLiquidity(
      tokenA.address,
      tokenB.address,
      amountADesired,
      amountBDesired,
      0, // amountAMin
      0, // amountBMin
      owner.address,
      Math.floor(Date.now() / 1000) + 60 * 10 // deadline
    );

    // 等待交易完成
    await tx.wait();

    // 3. 获取 Pair 地址
    const pairAddress = await factory.getPair(tokenA.address, tokenB.address);
    expect(pairAddress).to.not.equal(ethers.constants.AddressZero);

    // 4. 获取 Pair 合约实例
    // 注意：这里需要 UniswapV2Pair 的 artifact。
    // 如果你没有编译 UniswapV2Pair，可以使用 UniswapV2Factory 的 artifact 或者手动指定 ABI。
    // 通常 hardhat-uniswap-v2 插件或完整编译会包含它。
    // 这里假设你可以通过 getContractAt 获取。
    const pairContract = await ethers.getContractAt("UniswapV2Pair", pairAddress);

    // 5. 验证事件
    // addLiquidity 会触发 Factory 的 PairCreated (如果是第一次)
    // 也会触发 Pair 合约的 Mint 事件
    
    // 验证 Factory 发出了 PairCreated
    // 注意：如果 beforeEach 里已经创建过 Pair，这里可能不会触发。但在本测试结构中每次都是新的 factory，所以会触发。
    await expect(tx).to.emit(factory, "PairCreated")
        .withArgs(tokenA.address, tokenB.address, pairAddress, await factory.allPairsLength());

    // 验证 Pair 合约发出了 Mint 事件
    // Uniswap V2 Pair Mint 事件签名: Mint(address indexed sender, uint amount0, uint amount1)
    // 注意：sender 通常是 Router
    await expect(tx).to.emit(pairContract, "Mint")
        .withArgs(router.address, amountADesired, amountBDesired);

    // 6. 验证 LP 余额
    // 第一次添加流动性，LP 数量 = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY
    // sqrt(10 * 10) = 10 ETH = 10^19 wei
    // MINIMUM_LIQUIDITY = 1000 wei
    const expectedLiquidity = ethers.utils.parseEther("10").sub(ethers.BigNumber.from(1000));
    const lpBalance = await pairContract.balanceOf(owner.address);
    
    expect(lpBalance).to.equal(expectedLiquidity);
  });

  it("swapExactTokensForTokens: router 能正确执行代币兑换并触发 Swap 事件", async () => {
    const addAmountA = ethers.utils.parseEther("100");
    const addAmountB = ethers.utils.parseEther("100");

    // 授权并添加流动性
    await tokenA.approve(router.address, addAmountA);
    await tokenB.approve(router.address, addAmountB);

    await router.addLiquidity(
      tokenA.address,
      tokenB.address,
      addAmountA,
      addAmountB,
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 60 * 10
    );

    // 交换 1 TokenA -> TokenB
    const amountIn = ethers.utils.parseEther("1");
    const amountsOut = await router.getAmountsOut(amountIn, [tokenA.address, tokenB.address]);
    const expectedAmountOut = amountsOut[amountsOut.length - 1];
    console.log('amountsOut:', amountsOut.map(a => a.toString()));
    console.log('expectedAmountOut:', expectedAmountOut.toString());
      const approveTx = await tokenA.connect(owner).approve(router.address, amountIn);
    // 记录交换前 TokenB 余额
    const balanceBefore = await tokenB.balanceOf(owner.address);

    // Diagnostics: check allowance and balances
    const allowance = await tokenA.allowance(owner.address, router.address);
    const ownerTokenABalance = await tokenA.balanceOf(owner.address);
    const pairAddress = await factory.getPair(tokenA.address, tokenB.address);
    const pairContract = await ethers.getContractAt("UniswapV2Pair", pairAddress);
    const pairReserves = await pairContract.getReserves();

    console.log('Allowance for router:', allowance.toString());
    console.log('Owner tokenA balance:', ownerTokenABalance.toString());
    console.log('Pair reserves:', pairReserves[0].toString(), pairReserves[1].toString());

    // 授权 Router 转账 amountIn 并等待交易被挖矿
    const approveTx = await tokenA.connect(owner).approve(router.address, amountIn);
    await approveTx.wait();

    // Diagnostics after approval
    const allowanceAfterApprove = await tokenA.allowance(owner.address, router.address);
    const ownerTokenABalanceAfterApprove = await tokenA.balanceOf(owner.address);
    const pairTokenABalance = await tokenA.balanceOf(pairAddress);
    const pairTokenBBalance = await tokenB.balanceOf(pairAddress);

    console.log('Allowance after approve:', allowanceAfterApprove.toString());
    console.log('Owner tokenA balance after approve:', ownerTokenABalanceAfterApprove.toString());
    console.log('Pair token balances', pairTokenABalance.toString(), pairTokenBBalance.toString());

    // 执行 swap
    let swapTx;
    try {
      swapTx = await router.swapExactTokensForTokens(
        amountIn,
        0, // amountOutMin
        [tokenA.address, tokenB.address],
        owner.address,
        Math.floor(Date.now() / 1000) + 60 * 10
      );
      await swapTx.wait();
    } catch (err) {
      // Log detailed error info to troubleshoot revert
      console.error('Swap failed error:', err.message || err);
      if (err.error && err.error.message) console.error('Inner error:', err.error.message);
      if (err.data) console.error('Revert data:', err.data);
      // Also log allowance/balances for further insight
      const allowanceNow = await tokenA.allowance(owner.address, router.address);
      const ownerTokenANow = await tokenA.balanceOf(owner.address);
      const ownerTokenBNow = await tokenB.balanceOf(owner.address);
      const pairTokenANow = await tokenA.balanceOf(pairAddress);
      const pairTokenBNow = await tokenB.balanceOf(pairAddress);
      console.log('After failing swap allowance:', allowanceNow.toString());
      console.log('Owner tokenA balance now:', ownerTokenANow.toString());
      console.log('Owner tokenB balance now:', ownerTokenBNow.toString());
      console.log('Pair token balances now', pairTokenANow.toString(), pairTokenBNow.toString());
      throw err; // rethrow so test fails but we get diagnostics
    }

    // 获取 Pair 合约
    // pairContract and pairAddress already declared above

    // 计算 Swap 事件预期参数（基于 token0 / token1 排序）
    const token0Addr = await pairContract.token0();
    let amount0In, amount1In, amount0Out, amount1Out;

    if (tokenA.address.toLowerCase() === token0Addr.toLowerCase()) {
      amount0In = amountIn;
      amount1In = ethers.BigNumber.from(0);
      amount0Out = ethers.BigNumber.from(0);
      amount1Out = expectedAmountOut;
    } else {
      amount0In = ethers.BigNumber.from(0);
      amount1In = amountIn;
      amount0Out = expectedAmountOut;
      amount1Out = ethers.BigNumber.from(0);
    }

    // Diagnostics: 再次确认 allowance
    console.log('Allowance after approve (again):', allowanceAfterApprove.toString());

    // 验证 Pair 发出了 Swap 事件
    await expect(swapTx).to.emit(pairContract, "Swap")
      .withArgs(router.address, amount0In, amount1In, amount0Out, amount1Out, owner.address);

    // 验证 owner 收到了预期的 TokenB
    const balanceAfter = await tokenB.balanceOf(owner.address);
    expect(balanceAfter.sub(balanceBefore)).to.equal(expectedAmountOut);
  });

  it("manual pair.swap should work if direct token transfer then swap", async () => {
    // 新的 beforeEach 初始化，独立测试 pair.swap
    // Deploy fresh contracts per beforeEach already done
    const addAmountA = ethers.utils.parseEther("100");
    const addAmountB = ethers.utils.parseEther("100");

    await tokenA.approve(router.address, addAmountA);
    await tokenB.approve(router.address, addAmountB);

    await router.addLiquidity(
      tokenA.address,
      tokenB.address,
      addAmountA,
      addAmountB,
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 60 * 10
    );

    const amountIn = ethers.utils.parseEther("1");
    const amountsOut = await router.getAmountsOut(amountIn, [tokenA.address, tokenB.address]);
    const expectedAmountOut = amountsOut[amountsOut.length - 1];

    const pairAddr = await factory.getPair(tokenA.address, tokenB.address);
    const pair = await ethers.getContractAt("UniswapV2Pair", pairAddr);

    // 直接把 tokenA 发送到 pair 一笔交易
    await tokenA.transfer(pair.address, amountIn);

    // 直接调用 pair.swap
    await pair.swap(ethers.BigNumber.from(0), expectedAmountOut, owner.address, '0x');

    const ownerTokenBBalance = await tokenB.balanceOf(owner.address);
    expect(ownerTokenBBalance).to.be.gt(0);
  });

  it("simulate router using a separate signer (transferFrom + pair.swap)", async () => {
    const signers = await ethers.getSigners();
    const simRouter = signers[1];

    const addAmountA = ethers.utils.parseEther("100");
    const addAmountB = ethers.utils.parseEther("100");

    await tokenA.approve(router.address, addAmountA);
    await tokenB.approve(router.address, addAmountB);

    await router.addLiquidity(
      tokenA.address,
      tokenB.address,
      addAmountA,
      addAmountB,
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 60 * 10
    );

    const amountIn = ethers.utils.parseEther("1");
    const amountsOut = await router.getAmountsOut(amountIn, [tokenA.address, tokenB.address]);
    const expectedAmountOut = amountsOut[amountsOut.length - 1];

    const pairAddr = await factory.getPair(tokenA.address, tokenB.address);
    const pair = await ethers.getContractAt("UniswapV2Pair", pairAddr);

    // owner 授权 simRouter 转账
    await tokenA.connect(owner).approve(simRouter.address, amountIn);

    // simRouter 转移 owner 的 tokenA 到 pair
    await tokenA.connect(simRouter).transferFrom(owner.address, pairAddr, amountIn);

    // simRouter 调用 pair.swap
    await pair.connect(simRouter).swap(ethers.BigNumber.from(0), expectedAmountOut, owner.address, '0x');

    const ownerTokenBBalance = await tokenB.balanceOf(owner.address);
    expect(ownerTokenBBalance).to.be.gt(0);
  });
});