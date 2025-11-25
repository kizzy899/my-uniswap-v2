const { deployContract } = require("./utils");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

    // 部署Factory合约
    const factory = await deployContract("Factory", [deployer.address]);
    
    console.log("Factory deployment completed!");
    console.log("Factory address:", await factory.getAddress());
    console.log("FeeToSetter:", await factory.feeToSetter());

    return factory;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Deployment error:", error);
        process.exit(1);
    });