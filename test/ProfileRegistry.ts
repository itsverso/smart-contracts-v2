// import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
// import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("Profile Registry & Follow Registry", function () {
  let registry: any;
  let followRegistry: any;
  beforeEach(async function () {
    const [owner, otherAccount] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("ProfileRegistry");
    registry = await upgrades.deployProxy(Registry, [owner.address], {
      kind: "uups",
      initializer: "initialize",
    });

    await registry.deployed();

    const FollowRegistry = await ethers.getContractFactory("FollowRegistry");
    followRegistry = await upgrades.deployProxy(
      FollowRegistry,
      [owner.address, registry.address],
      {
        kind: "uups",
        initializer: "initialize",
      }
    );

    await followRegistry.deployed();

    await registry.setFollowRegistryAddress(followRegistry.address);
  });
  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      expect(await registry.owner()).to.equal(owner.address);
    });

    it("Should return the right contract name", async function () {
      expect(await registry.name()).to.equal("Verso Profile Registry");
    });

    it("Should return the right contract name for follow registry", async function () {
      expect(await followRegistry.name()).to.equal("Verso Follow Registry");
    });

    it("Should set the right owner for Follow Registry", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      expect(await followRegistry.owner()).to.equal(owner.address);
    });

    it("Should set the right profile registry address", async function () {
      expect(await followRegistry.getRegistry()).to.equal(registry.address);
    });

    it("Should set the right follow registry address", async function () {
      await registry.setFollowRegistryAddress(followRegistry.address);
      expect(await registry.followRegistryAddress()).to.equal(
        followRegistry.address
      );
    });
  });

  describe("Registering Profiles", function () {
    beforeEach(async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      await registry.registerProfile(
        owner.address,
        "itsahandle",
        "www.url.com"
      );
    });

    it("Should increment token Ids", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      await registry
        .connect(otherAccount)
        .registerProfile(otherAccount.address, "newhandle", "www.url.com");
      let tokenId = await registry.getTokenId();
      expect(tokenId).to.equal("3");
    });

    it("Should set the right owner", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      let tokenId = await registry.addressToProfileID(owner.address);
      expect(tokenId).to.equal("1");
    });

    it("Should NOT allow owner to mint twice", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      await expect(
        registry
          .connect(otherAccount)
          .registerProfile(owner.address, "itsahandle", "www.url.com")
      ).to.be.revertedWith("Already has profile");
    });

    it("Should NOT allow to mint same handle twice", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      await expect(
        registry
          .connect(otherAccount)
          .registerProfile(otherAccount.address, "itsahandle", "www.url.com")
      ).to.be.revertedWith("Handle already taken");
    });

    it("Should set the right handle", async function () {
      let profile = await registry.getProfileByID("1");
      expect(profile.handle).to.equal("itsahandle");
    });

    it("Should set the right metadata URI", async function () {
      let profile = await registry.getProfileByID("1");
      expect(profile.metadataURI).to.equal("www.url.com");
    });

    it("Should mint the first follow NFT", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      let balance = await followRegistry.balanceOf(owner.address, 1);
      expect(balance).to.equal("1");
    });
  });

  describe("Followings", function () {
    it("Should allow to follow a user profile", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      await followRegistry.connect(otherAccount).follow(1);
      let balance = await followRegistry.balanceOf(otherAccount.address, 1);
      expect(balance).to.equal("1");
    });

    it("Should allow to unfollow a user profile", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      await followRegistry.connect(otherAccount).follow(1);
      await followRegistry.connect(otherAccount).unfollow(1);
      let balance = await followRegistry.balanceOf(otherAccount.address, 1);
      expect(balance).to.equal("0");
    });

    it("Should NOT allow to follow a user profile", async function () {
      const [owner, otherAccount] = await ethers.getSigners();
      await followRegistry.connect(otherAccount).follow(1);
      await expect(
        followRegistry.connect(otherAccount).follow(1)
      ).to.be.revertedWith("Already a follower");
    });
  });
});
