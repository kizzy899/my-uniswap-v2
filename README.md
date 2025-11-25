# Basic Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```
## Environment variables (.env)

This project uses a `.env` file for network RPC URLs and private keys. For security, never commit your real `.env` file — use the provided `.env.example` as a template.

Required (example) variables in `.env`:

- `SEPOLIA_RPC_URL` — RPC endpoint for Sepolia (Infura, Alchemy, etc.)
- `SEPOLIA_PRIVATE_KEY` — Private key for deployer account (hex, 0x...)
- `LOCAL_NETWORK_RPC_URL` — Local node URL (default: http://127.0.0.1:8545)
- `ETHERSCAN_API_KEY` — (Optional) for contract verification

Usage:

1. Copy `.env.example` to `.env` and fill in values.
2. Install dependencies: `npm install` (this project uses Hardhat).
3. Run tasks, e.g. `npx hardhat compile` or `npx hardhat node`.

Make sure `.env` is listed in `.gitignore` to avoid accidental commits.
