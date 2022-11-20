# Introduction to LSSVM-unlocked
LSSVM-unlocked provides a Sudoswap style experience while keeping your NFT in your own wallet. So you can interact with other marketplaces while listing your NFT in LSSVM-unlocked. There is also another possibility to do a dual listing with classival LSSVM which will be explained later.

# Major difference with original LSSVM
- Resolved the circular dependency issue with `IRouter.sol`
- Only `LSSVMPairMissingEnumerable` is still in use out of the two base variants
- NFTs are transacted through `LSSVMPairFactory`. Extra function added called `requestNFTTransferFrom`. So users set approval of their NFTs to LSSVMPair Factory
- `getHeldIds` check for user's approval instead of NFT's presence inside the contract
- ETH pairs use WETH instead for future composability purposes. So all ETH functions are removed to save deployment gas
- `CREATE2` instead of `CREATE` is used for address prediction
- Original tests are removed because they are no longer relavant

# Dual listing with SudoSwap
Dual listing with SudoSwap (or any other LSSVM based marketplaces) is made possible by giving `LSSVMFactory` a sister factory (which is Sudo's very own factory). The pair creates another pair on Sudo through the sister factory (see `createSudoPool`) and effectively owns that pair. All NFTs listed are then stored in the Sudo pool (no unlocked listing). If an NFT is purchased through n00dle instead of Sudo, the n00dle pool withdraws from the Sudo pool and give the NFT to the buyer.

# Usage
Contracts are modified so that they can be compiled one-click on Remix ide.

# Folder structure
```
.
├── lib                     # Openzeppelin, Solmate, etc.
├── src                     # Contracts
│   ├── bonding-curves      # Bonding curves (no modification is done)
│   └── lib                 # Specific libraries (EIP-1167 cloner, etc.)
└── README.md
```

# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
