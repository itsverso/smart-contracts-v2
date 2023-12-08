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
    const MODERATOR_HASH =
      "0x44a854cabd360644e908fcd642b33fedfb60c399d7b1e7e2051275f0b09b0be5";

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
      const CollectionInstance = await ethers.getContractFactory("Collection");
      collection = CollectionInstance.attach(receipt.logs[0].address);
    });

    it("Should DEPLOY new instance of Collection and set NAME", async function () {
      expect(await collection.name()).to.equal("NAME");
    });

    it("Should DEPLOY new instance of Collection and set first MODERATOR", async function () {
      expect(await collection.hasRole(MODERATOR_HASH, owner.address)).to.be
        .true;
    });

    describe("Creating Versos", function () {
      //////////////////////////////////////
      //// Creating VERSOS
      ////////////////////////////////////

      beforeEach(async function () {
        await collection.create(
          "www.url.com",
          owner.address,
          "0x0000000000000000000000000000000000000000",
          marketMaster.address,
          "100000000000000000",
          0,
          true,
          true
        );
      });

      it("Should create a LISTED token", async function () {
        expect(await marketMaster.tokenSupply(collection.address, 1)).to.equal(
          1
        );
      });

      it("Should match token supplies", async function () {
        let supplyInCollection = await collection.tokenSupply(1);
        let marketSupply = await marketMaster.tokenSupply(
          collection.address,
          1
        );
        expect(supplyInCollection).to.equal(marketSupply);
      });

      it("Should allow to BUY/COLLECT bonded token", async function () {
        const [owner, otherAccount] = await ethers.getSigners();

        let price = await marketMaster.getBuyPriceAfterFee(
          collection.address,
          1,
          1
        );

        await collection
          .connect(otherAccount)
          .collect(1, otherAccount.address, 1, {
            value: price,
          });

        let marketSupply = await marketMaster.tokenSupply(
          collection.address,
          1
        );

        expect(marketSupply).to.equal(2);
      });

      it("Should allow to BUY/COLLECT arbitrary number of bonded tokens", async function () {
        const [owner, otherAccount] = await ethers.getSigners();
        let amountToBuy = 10;
        let price = await marketMaster.getBuyPriceAfterFee(
          collection.address,
          1,
          amountToBuy
        );
        await collection
          .connect(otherAccount)
          .collect(1, otherAccount.address, amountToBuy, {
            value: price,
          });
        let marketSupply = await marketMaster.tokenSupply(
          collection.address,
          1
        );
        expect(marketSupply).to.equal(11);
      });

      it("Should allow to SELL/WITHDRAW a bonded token", async function () {
        const [owner, otherAccount] = await ethers.getSigners();
        let amountToBuy = 10;
        let price = await marketMaster.getBuyPriceAfterFee(
          collection.address,
          1,
          amountToBuy
        );
        await collection
          .connect(otherAccount)
          .collect(1, otherAccount.address, amountToBuy, {
            value: price,
          });

        await collection.connect(otherAccount).burn(1, 1);
        let marketSupply = await marketMaster.tokenSupply(
          collection.address,
          1
        );
        expect(marketSupply).to.equal(10);
      });

      it("Should allow to SELL/WITHDRAW an arbitrary number of bonded tokens", async function () {
        const [owner, otherAccount] = await ethers.getSigners();
        let amountToBuy = 10;
        let price = await marketMaster.getBuyPriceAfterFee(
          collection.address,
          1,
          amountToBuy
        );
        await collection
          .connect(otherAccount)
          .collect(1, otherAccount.address, amountToBuy, {
            value: price,
          });

        await collection.connect(otherAccount).burn(1, 8);
        let marketSupply = await marketMaster.tokenSupply(
          collection.address,
          1
        );
        expect(marketSupply).to.equal(3);
      });

      it("Should have matching supplies", async function () {
        const [owner, otherAccount] = await ethers.getSigners();
        let amountToBuy = 10;
        let price = await marketMaster.getBuyPriceAfterFee(
          collection.address,
          1,
          amountToBuy
        );
        await collection
          .connect(otherAccount)
          .collect(1, otherAccount.address, amountToBuy, {
            value: price,
          });

        let collectionSupply = await collection.tokenSupply(1);
        let marketSupply = await marketMaster.tokenSupply(
          collection.address,
          1
        );
        expect(marketSupply).to.equal(collectionSupply);
      });

      it("Should allow collections to OWN versos", async function () {
        await collection.create(
          "www.url.com",
          collection.address,
          "0x0000000000000000000000000000000000000000",
          marketMaster.address,
          "100000000000000000",
          0,
          true,
          true
        );
        let balance = await collection.balanceOf(collection.address, 2);
        expect(balance).to.equal("1");
      });

      it("Should allow collections to BURN versos", async function () {
        await collection.create(
          "www.url.com",
          collection.address,
          "0x0000000000000000000000000000000000000000",
          marketMaster.address,
          "100000000000000000",
          0,
          true,
          true
        );
        await collection.withdraw(collection.address, 2, 1);
        let balance = await collection.balanceOf(collection.address, 2);
        expect(balance).to.equal("0");
      });

      it("Should allow to create GATED collections", async function () {
        const [owner, otherAccount] = await ethers.getSigners();
        const Registry = await ethers.getContractFactory("ProfileRegistry");
        const registry = await upgrades.deployProxy(Registry, [owner.address], {
          kind: "uups",
          initializer: "initialize",
        });
        await registry.deployed();
        await registry.registerProfile(
          owner.address,
          "itsahandle",
          "www.url.com"
        );

        let tx = await collectionFactory.createCollection({
          _collectionName: "NEW COLLECTION",
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
        await collection.withdraw(collection.address, 2, 1);
        let balance = await collection.balanceOf(collection.address, 2);
        expect(balance).to.equal("0");
      });
    });
  });
});
