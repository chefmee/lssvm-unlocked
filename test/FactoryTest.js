const { time, loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("Factory Test", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFactoryContractsFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Pair = await ethers.getContractFactory("LSSVMPairMissingEnumerableERC20");
    const pair = await Pair.deploy();

    const LSSVMFactory = await ethers.getContractFactory("contracts/src/LSSVMPairFactory.sol:LSSVMPairFactory")
    const lssvmFactory = await LSSVMFactory.deploy(pair.address, owner.address, "50000000000000000", "0x0000000000000000000000000000000000000000")

    const MockNFT = await ethers.getContractFactory('MockNFT')
    const mockNFT = await MockNFT.deploy()

    const WETH = await ethers.getContractFactory("WETH9")
    const weth = await WETH.deploy()

    const LinearCurve = await ethers.getContractFactory("LinearCurve")
    const linearCurve = await LinearCurve.deploy()

    const LSSVMRouter = await ethers.getContractFactory("LSSVMRouter")
    const lssvmRouter = await LSSVMRouter.deploy(lssvmFactory.address)

    await lssvmFactory.setBondingCurveAllowed(linearCurve.address, true)
    await lssvmFactory.setRouterAllowed(lssvmRouter.address, true)

    const tx = await lssvmFactory.createPairERC20([weth.address, mockNFT.address, linearCurve.address, owner.address, 1, "1000000000000000", 0, "10000000000000000", [1, 2, 3, 5, 6], 0], weth.address, false)
    const res = await tx.wait()
    const NFTPoolAddress = res.events[3].args.poolAddress

    await weth.approve(lssvmFactory.address, "30000000000000000")
    await weth.connect(otherAccount).approve(lssvmRouter.address, "50000000000000000000000", {from: otherAccount.address})

    const tx2 = await lssvmFactory.createPairERC20([weth.address, mockNFT.address, linearCurve.address, owner.address, 0, "1000000000000000", 0, "10000000000000000", [], "30000000000000000"], weth.address, false, {value: "30000000000000000"})
    const res2 = await tx2.wait()
    const TokenPoolAddress = res2.events[3].args.poolAddress

    const tx3 = await lssvmFactory.connect(otherAccount).createPairERC20([weth.address, mockNFT.address, linearCurve.address, otherAccount.address, 1, "1000000000000000", 0, "10000000000000000", [6], 0], weth.address, false)
    const res3 = await tx3.wait()
    const NFTPool2Address = res3.events[3].args.poolAddress

    await mockNFT.transferFrom(owner.address, otherAccount.address, 5)
    await mockNFT.transferFrom(owner.address, otherAccount.address, 6)
    await mockNFT.setApprovalForAll(lssvmFactory.address, true)
    await mockNFT.connect(otherAccount).setApprovalForAll(lssvmFactory.address, true, {from: otherAccount.address})

    return { pair, lssvmFactory, lssvmRouter, mockNFT, weth, linearCurve, owner, otherAccount, NFTPoolAddress, TokenPoolAddress, NFTPool2Address };
  }

  describe("Can buy sell unlocked", function () {
    it("Should buy unlocked NFTs", async function () {
      const { NFTPoolAddress, weth, mockNFT, linearCurve, otherAccount, lssvmRouter } = await loadFixture(deployFactoryContractsFixture);
      await lssvmRouter.connect(otherAccount).swapETHToWETHForSpecificNFTs([[NFTPoolAddress, [2]]], "50000000000000000", otherAccount.address, (Date.now()/1000+1000).toFixed(0), weth.address, {value: "50000000000000000"})
    });

    it("Should not buy non-listed unlocked NFTs", async function () {
      const { NFTPoolAddress, weth, mockNFT, linearCurve, otherAccount, lssvmRouter } = await loadFixture(deployFactoryContractsFixture);
      try {
        await lssvmRouter.connect(otherAccount).swapETHToWETHForSpecificNFTs([[NFTPoolAddress, [0, 4]]], "50000000000000000", otherAccount.address, (Date.now()/1000+1000).toFixed(0), weth.address, {value: "50000000000000000"})
        expect(true).eq(false)
      } catch (e) {
        expect(e.message).contains("NFT not permitted!")
      }
    });

    it("Should not buy other people's listed unlocked NFTs", async function () {
      const { NFTPoolAddress, weth, mockNFT, linearCurve, otherAccount, lssvmRouter } = await loadFixture(deployFactoryContractsFixture);
      try {
        await lssvmRouter.connect(otherAccount).swapETHToWETHForSpecificNFTs([[NFTPoolAddress, [5]]], "50000000000000000", otherAccount.address, (Date.now()/1000+1000).toFixed(0), weth.address, {value: "50000000000000000"})
        expect(true).eq(false)
      } catch (e) {
        expect(e.message).contains("NFT not owned by pool owner")
      }
    });

    it("Should not buy other people's unlisted unlocked NFTs", async function () {
      const { NFTPoolAddress, weth, mockNFT, linearCurve, otherAccount, lssvmRouter } = await loadFixture(deployFactoryContractsFixture);
      try {
        await lssvmRouter.connect(otherAccount).swapETHToWETHForSpecificNFTs([[NFTPoolAddress, [6]]], "50000000000000000", otherAccount.address, (Date.now()/1000+1000).toFixed(0), weth.address, {value: "50000000000000000"})
        expect(true).eq(false)
      } catch (e) {
        expect(e.message).contains("NFT not owned by pool owner")
      }
      expect(true)
    });

    
  });

  
});
