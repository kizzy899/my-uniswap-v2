const { ethers } = require("hardhat");
const { deployContract, sortTokens, calculatePairAddress } = require("./utils");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying test environment with account:", deployer.address);

    // 1. 部署测试代币
    console.log("\n1. Deploying test tokens...");
    const tokenA = await deployContract("ERC20Mock", ["TokenA", "TKA", ethers.utils.parseEther("1000000")]);
    const tokenB = await deployContract("ERC20Mock", ["TokenB", "TKB", ethers.utils.parseEther("1000000")]);

    const tokenAAddress = tokenA.address;  // 使用 .address 属性
    const tokenBAddress = tokenB.address;  // 使用 .address 属性
    console.log("TokenA address:", tokenAAddress);
    console.log("TokenB address:", tokenBAddress);

    // 2. 部署Factory合约
    console.log("\n2. Deploying Factory...");
    const factory = await deployContract("Factory", []); // 不传参数了
    const factoryAddress = factory.address;  // 使用 .address 属性
    
    // 3. 创建交易对
    console.log("\n3. Creating pair...");
    const tx = await factory.createPair(tokenAAddress, tokenBAddress);
    const receipt = await tx.wait();
    
    // 获取PairCreated事件
    const pairCreatedEvent = receipt.logs.find(log => {
        try {
            return factory.interface.parseLog(log)?.name === 'PairCreated';
        } catch {
            return false;
        }
    });

    let pairAddress;
    if (pairCreatedEvent) {
        const parsedEvent = factory.interface.parseLog(pairCreatedEvent);
        pairAddress = parsedEvent.args.pair;
    } else {
        // 备用方法：直接从factory获取
        pairAddress = await factory.getPair(tokenAAddress, tokenBAddress);
    }
    
    console.log("Pair created at:", pairAddress);

    // 4. 验证Pair合约
    const Pair = await ethers.getContractFactory("Pair");
    const pair = Pair.attach(pairAddress);
    
    console.log("\n4. Verifying pair contract...");
    console.log("Pair token0:", await pair.token0());
    console.log("Pair token1:", await pair.token1());
    console.log("Pair factory:", await pair.factory());

    // 5. 测试CREATE2地址计算
    console.log("\n5. Testing CREATE2 address calculation...");
    const pairBytecode = (await ethers.getContractFactory("Pair")).bytecode;
    const calculatedAddress = calculatePairAddress(
        factoryAddress,
        tokenAAddress,
        tokenBAddress,
        pairBytecode
    );
    console.log("Calculated address:", calculatedAddress);
    console.log("Actual address:   ", pairAddress);
    console.log("Address match:", calculatedAddress.toLowerCase() === pairAddress.toLowerCase());

    return {
        factory,
        tokenA,
        tokenB,
        pair: pair
    };
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Deployment error:", error);
        process.exit(1);
    });
