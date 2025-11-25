// scripts/deploy/utils.js 工具函数脚本

const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

// 如果要使用 CREATE2 生成确定性地址，可以定义 salt
exports.getCreate2Salt = () => ethers.utils.formatBytes32String("Factory_v1");

// 保存部署信息到 deployments/network/...
exports.saveDeployment = async (network, info) => {
    const dir = path.join(__dirname, "../../deployments", network);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const stamp = new Date().toISOString().slice(0, 19).replace(/:/g, "-");
    
    fs.writeFileSync(
        path.join(dir, `${info.contract}.json`),
        JSON.stringify(info, null, 2)
    );
    
    fs.writeFileSync(
        path.join(dir, `${stamp}_${info.contract}.json`),
        JSON.stringify(info, null, 2)
    );
    
    console.log("Deployment saved to", path.join(dir, `${info.contract}.json`));
};

// 可选：读取部署信息
exports.getDeployment = (network, contractName) => {
    const filePath = path.join(__dirname, "../../deployments", network, `${contractName}.json`);
    if (fs.existsSync(filePath)) {
        return JSON.parse(fs.readFileSync(filePath, "utf8"));
    }
    return null;
};

// 可选：验证合约地址
exports.isValidAddress = (address) => {
    try {
        ethers.utils.getAddress(address);
        return true;
    } catch {
        return false;
    }
};