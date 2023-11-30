// import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
// import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("Collections", function () {
  let owner: any;
  let otherOwner: any;
  let collectionFactory: any;
  let collectionImplementation: any;
  let collectionRegistry: any;
  let marketMaster: any;
  beforeEach(async function () {
    const [account, otherAccount] = await ethers.getSigners();
    owner = account;
    otherOwner = otherAccount;

    //////////////////////////////////////
    //// Market Master
    /////////////////////////////////////
    const MarketMaster = await ethers.getContractFactory("MarketMaster");
    // Deploy proxy
    marketMaster = await upgrades.deployProxy(
      MarketMaster,
      [
        owner.address,
        owner.address,
        "005000000000000000",
        "005000000000000000",
        "000077777777777777",
      ],
      {
        kind: "uups",
        initializer: "initialize",
      }
    );
    // Await
    await marketMaster.deployed();

    //////////////////////////////////////
    //// Collection Implementation
    /////////////////////////////////////
    const CollectionImplementation = await ethers.getContractFactory(
      "Collection"
    );
    // Deploy proxy
    collectionImplementation = await CollectionImplementation.deploy();
    // Await
    await collectionImplementation.deployed();

    //////////////////////////////////////
    //// Collection Factory
    /////////////////////////////////////

    const CollectionFactory = await ethers.getContractFactory(
      "CollectionFactory"
    );
    // Deploy proxy
    collectionFactory = await CollectionFactory.deploy(
      collectionImplementation.address,
      owner.address
    );
    // Await
    await collectionFactory.deployed();

    //////////////////////////////////////
    //// Collection Registry
    /////////////////////////////////////

    const CollectionRegistry = await ethers.getContractFactory(
      "CollectionRegistry"
    );
    // Deploy proxy
    collectionRegistry = await upgrades.deployProxy(
      CollectionRegistry,
      [owner.address, collectionFactory.address],
      {
        kind: "uups",
        initializer: "initialize",
      }
    );
    // Await
    await collectionRegistry.deployed();

    await collectionFactory.setCollectionRegistryAddress(
      collectionRegistry.address
    );
  });

  describe("Deployment", function () {
    //////////////////////////////////////
    //// Deployments
    /////////////////////////////////////
    it("Should deploy MARKET master and set owner", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      expect(await marketMaster.owner()).to.equal(owner.address);
    });

    it("Should deploy FACTORY and set owner", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      expect(await collectionFactory.owner()).to.equal(owner.address);
    });

    it("Should deploy REGISTRY and set owner", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      expect(await collectionRegistry.owner()).to.equal(owner.address);
    });
  });

  describe("Creating Collections", function () {
    //////////////////////////////////////
    //// Creating Collection
    /////////////////////////////////////
    let collection: any;
    beforeEach(async function () {
      const [account, otherAccount] = await ethers.getSigners();
      let tx = await collectionFactory.createCollection({
        _collectionName: "NAME",
        _collectionMetadataURI: "www.url.com",
        _readType: 0,
        _writeType: 1,
        _collectionPermissions: "0x0000000000000000000000000000000000000000",
        _minimumBalance: 0,
        _marketAddress: marketMaster.address,
        _supplyLimit: 10,
        _tokenPrice: 0,
        _isBonded: true,
      });

      let receipt = await tx.wait();
      console.log(receipt);
    });

    it("DEPLOY new instance of Collection and set NAME", async function () {});
  });
});
