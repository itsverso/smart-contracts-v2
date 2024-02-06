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
  let simpleMarket: any;
  let baseFee = "55555555555555"

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
    //// Simple Market 
    /////////////////////////////////////
    const SimpleMarket = await ethers.getContractFactory("SimpleMarketMaster");
    // Deploy proxy
    simpleMarket = await upgrades.deployProxy(
      SimpleMarket,
      [
        owner.address,
        owner.address,
        baseFee,
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

      describe("BONDED", function () {
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
            .collect(1, otherAccount.address, 1, otherAccount.address, {
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
            .collect(1, otherAccount.address, amountToBuy, otherAccount.address, {
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
            .collect(1, otherAccount.address, amountToBuy, otherAccount.address, {
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
            .collect(1, otherAccount.address, amountToBuy, otherAccount.address, {
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
            .collect(1, otherAccount.address, amountToBuy, otherAccount.address, {
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
      })

      
      describe("Flat Fee", function () {
        beforeEach(async function () {
          await collection.create(
            "www.url.com",
            owner.address,
            "0x0000000000000000000000000000000000000000",
            simpleMarket.address,
            "100000000000000000",
            0,
            true,
            false
          );
        });
  
        it("Should create a NON-BONDED LISTED token on SIMPLE MARKET", async function () {
          await collection.create(
            "www.url2.com",
            owner.address,
            "0x0000000000000000000000000000000000000000",
            simpleMarket.address,
            "100000000000000000",
            0,
            true,
            false
          );

          let uri = await collection.uri(2)
          expect(uri).to.equal("www.url2.com");
        });
  
        it("Should match token supplies", async function () {
          let supplyInCollection = await collection.tokenSupply(1);
          let marketSupply = await simpleMarket.tokenSupply(
            collection.address,
            1
          );
          expect(supplyInCollection).to.equal(marketSupply);
        });

        it("Should set the right supply limit", async function () {
          let tokenSupplyLimit = await simpleMarket.supplyLimit(
            collection.address,
            1
          );
          expect(tokenSupplyLimit).to.equal("100000000000000000");
        });

        it("Should set the right base token price", async function () {
          let tokenPrice = await simpleMarket.getBuyPrice(
            collection.address,
            1, 
            1
          );
          expect(tokenPrice).to.equal(baseFee);
        });
  
        it("Should allow to BUY/COLLECT bonded token", async function () {
          const [owner, otherAccount] = await ethers.getSigners();

          await collection.create(
            "www.url2.com",
            owner.address,
            "0x0000000000000000000000000000000000000000",
            simpleMarket.address,
            "100000000000000000",
            0,
            true,
            false
          );
  
          let price = await simpleMarket.getBuyPriceAfterFee(
            collection.address,
            2,
            1
          );

          let parsedPrice = price.toString() / 100000000000000000
          let balance = await otherAccount.getBalance()
          
          
          await collection
            .connect(otherAccount)
            .collect(2, otherAccount.address, 1, otherAccount.address, {
              value: ethers.utils.parseEther(parsedPrice.toString()),
            });
  
          let marketSupply = await simpleMarket.tokenSupply(
            collection.address,
            2
          );
          
  
          expect(marketSupply).to.equal(2);
          
        });
  
        it("Should allow to BUY/COLLECT arbitrary number of bonded tokens", async function () {
          const [owner, otherAccount] = await ethers.getSigners();

          await collection.create(
            "www.url2.com",
            owner.address,
            "0x0000000000000000000000000000000000000000",
            simpleMarket.address,
            "100000000000000000",
            0,
            true,
            false
          );
  
          let price = await simpleMarket.getBuyPriceAfterFee(
            collection.address,
            2,
            11
          );

          let parsedPrice = price.toString() / 100000000000000000
          let balance = await otherAccount.getBalance()
          
          
          await collection
            .connect(otherAccount)
            .collect(2, otherAccount.address, 11, otherAccount.address, {
              value: ethers.utils.parseEther(parsedPrice.toString()),
            });
  
          let marketSupply = await simpleMarket.tokenSupply(
            collection.address,
            2
          );
          
  
          expect(marketSupply).to.equal(12);
        });
      });
    });
  });
});
