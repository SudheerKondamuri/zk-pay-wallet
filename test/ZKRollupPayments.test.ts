import { expect } from "chai";
import hre from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { StubZKVerifier, ZKRollupPayments } from "../typechain-types";

describe("ZKRollupPayments & StubZKVerifier", function () {
  let verifier: StubZKVerifier, rollup: ZKRollupPayments;
  let owner: HardhatEthersSigner, relayer: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner;

  beforeEach(async function () {
    [owner, relayer, user1, user2] = await hre.ethers.getSigners();

    const StubZKVerifierFactory = await hre.ethers.getContractFactory("StubZKVerifier");
    verifier = (await StubZKVerifierFactory.deploy()) as StubZKVerifier;

    const ZKRollupPaymentsFactory = await hre.ethers.getContractFactory("ZKRollupPayments");
    rollup = (await ZKRollupPaymentsFactory.deploy(await verifier.getAddress())) as ZKRollupPayments;
  });

  describe("StubZKVerifier", function () {
    it("verifyProof should always return true", async function () {
      const result = await verifier.verifyProof("0x1234", [123, 456]);
      expect(result).to.be.true;
    });
  });

  describe("Deployment & Initial State", function () {
    it("should set correct verifier address", async function () {
      expect(await rollup.verifier()).to.equal(await verifier.getAddress());
    });

    it("should set initial currentStateRoot to bytes32(0)", async function () {
      expect(await rollup.currentStateRoot()).to.equal(hre.ethers.ZeroHash);
    });

    it("should set owner as initial relayer", async function () {
      expect(await rollup.isRelayer(owner.address)).to.be.true;
    });

    it("should start with batchCount 0", async function () {
      expect(await rollup.batchCount()).to.equal(0n);
    });

    it("should revert deployment if verifier is zero address", async function () {
      const ZKRollupPaymentsFactory = await hre.ethers.getContractFactory("ZKRollupPayments");
      await expect(ZKRollupPaymentsFactory.deploy(hre.ethers.ZeroAddress)).to.be.revertedWith(
        "ZKRollup: zero address"
      );
    });
  });

  describe("Relayer & Ownership Management", function () {
    it("owner can add and remove relayer", async function () {
      expect(await rollup.isRelayer(relayer.address)).to.be.false;

      await expect(rollup.addRelayer(relayer.address))
        .to.emit(rollup, "RelayerAdded")
        .withArgs(relayer.address);
      expect(await rollup.isRelayer(relayer.address)).to.be.true;

      await expect(rollup.removeRelayer(relayer.address))
        .to.emit(rollup, "RelayerRemoved")
        .withArgs(relayer.address);
      expect(await rollup.isRelayer(relayer.address)).to.be.false;
    });

    it("reverts when adding zero address relayer", async function () {
      await expect(rollup.addRelayer(hre.ethers.ZeroAddress)).to.be.revertedWith(
        "ZKRollup: zero address"
      );
    });

    it("non-owner cannot add relayer", async function () {
      await expect(
        rollup.connect(user1).addRelayer(user2.address)
      ).to.be.revertedWith("ZKRollup: not owner");
    });

    it("owner can transfer ownership", async function () {
      await expect(rollup.transferOwnership(user1.address))
        .to.emit(rollup, "OwnershipTransferred")
        .withArgs(owner.address, user1.address);

      expect(await rollup.owner()).to.equal(user1.address);
    });

    it("reverts transfer ownership to zero address", async function () {
      await expect(rollup.transferOwnership(hre.ethers.ZeroAddress)).to.be.revertedWith(
        "ZKRollup: zero address"
      );
    });
  });

  describe("Pausable Controls", function () {
    it("owner can pause and unpause contract", async function () {
      expect(await rollup.paused()).to.be.false;

      await expect(rollup.pause())
        .to.emit(rollup, "Paused")
        .withArgs(owner.address);
      expect(await rollup.paused()).to.be.true;

      await expect(rollup.unpause())
        .to.emit(rollup, "Unpaused")
        .withArgs(owner.address);
      expect(await rollup.paused()).to.be.false;
    });

    it("blocks deposit, commitBatch, and withdraw when paused", async function () {
      await rollup.pause();

      await expect(rollup.connect(user1).deposit({ value: hre.ethers.parseEther("1.0") })).to.be.revertedWith(
        "ZKRollup: paused"
      );

      const newStateRoot = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("newRoot"));
      const batchHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("batch1"));
      await expect(
        rollup.commitBatch(newStateRoot, batchHash, 1, "0x", [])
      ).to.be.revertedWith("ZKRollup: paused");

      await expect(rollup.connect(user1).withdraw(hre.ethers.parseEther("1.0"))).to.be.revertedWith(
        "ZKRollup: paused"
      );
    });
  });

  describe("Deposits", function () {
    it("user can deposit ETH and event is emitted", async function () {
      const depositAmount = hre.ethers.parseEther("1.0");

      await expect(rollup.connect(user1).deposit({ value: depositAmount }))
        .to.emit(rollup, "Deposited")
        .withArgs(user1.address, depositAmount, depositAmount);

      expect(await rollup.deposits(user1.address)).to.equal(depositAmount);
    });

    it("reverts 0 amount deposit", async function () {
      await expect(rollup.connect(user1).deposit({ value: 0 })).to.be.revertedWith(
        "ZKRollup: amount zero"
      );
    });
  });

  describe("Commit Batch", function () {
    it("whitelisted relayer can commit batch", async function () {
      await rollup.addRelayer(relayer.address);

      const newStateRoot = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("newRoot"));
      const batchHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("batch1"));
      const txCount = 5;

      await expect(
        rollup.connect(relayer).commitBatch(newStateRoot, batchHash, txCount, "0x", [])
      )
        .to.emit(rollup, "BatchCommitted")
        .withArgs(0n, newStateRoot, batchHash, txCount, relayer.address);

      expect(await rollup.currentStateRoot()).to.equal(newStateRoot);
      expect(await rollup.batchCount()).to.equal(1n);

      const batch = await rollup.batches(0);
      expect(batch.oldStateRoot).to.equal(hre.ethers.ZeroHash);
      expect(batch.newStateRoot).to.equal(newStateRoot);
      expect(batch.txCount).to.equal(5n);
      expect(batch.batchHash).to.equal(batchHash);
      expect(batch.relayer).to.equal(relayer.address);
    });

    it("non-relayer cannot commit batch", async function () {
      const newStateRoot = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("newRoot"));
      const batchHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("batch1"));

      await expect(
        rollup.connect(user1).commitBatch(newStateRoot, batchHash, 1, "0x", [])
      ).to.be.revertedWith("ZKRollup: not relayer");
    });

    it("reverts if newStateRoot is zero or txCount is 0", async function () {
      const batchHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("batch1"));

      await expect(
        rollup.commitBatch(hre.ethers.ZeroHash, batchHash, 1, "0x", [])
      ).to.be.revertedWith("ZKRollup: invalid state root");

      const newStateRoot = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("newRoot"));
      await expect(
        rollup.commitBatch(newStateRoot, batchHash, 0, "0x", [])
      ).to.be.revertedWith("ZKRollup: empty batch");
    });

    it("validates publicInputs matching old and new state roots", async function () {
      const newStateRoot = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("newRoot"));
      const batchHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("batch1"));

      const wrongOldRoot = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("wrongOld"));
      await expect(
        rollup.commitBatch(newStateRoot, batchHash, 1, "0x", [wrongOldRoot, newStateRoot])
      ).to.be.revertedWith("ZKRollup: old state root mismatch");

      const wrongNewRoot = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("wrongNew"));
      await expect(
        rollup.commitBatch(newStateRoot, batchHash, 1, "0x", [hre.ethers.ZeroHash, wrongNewRoot])
      ).to.be.revertedWith("ZKRollup: new state root mismatch");
    });
  });

  describe("Withdrawals", function () {
    it("user can withdraw deposited ETH", async function () {
      const depositAmount = hre.ethers.parseEther("2.0");
      const withdrawAmount = hre.ethers.parseEther("1.0");

      await rollup.connect(user1).deposit({ value: depositAmount });

      await expect(rollup.connect(user1).withdraw(withdrawAmount))
        .to.emit(rollup, "Withdrawn")
        .withArgs(user1.address, withdrawAmount);

      expect(await rollup.deposits(user1.address)).to.equal(depositAmount - withdrawAmount);
    });

    it("reverts if withdrawal exceeds balance or is zero", async function () {
      const depositAmount = hre.ethers.parseEther("1.0");
      await rollup.connect(user1).deposit({ value: depositAmount });

      await expect(
        rollup.connect(user1).withdraw(0)
      ).to.be.revertedWith("ZKRollup: amount zero");

      await expect(
        rollup.connect(user1).withdraw(hre.ethers.parseEther("2.0"))
      ).to.be.revertedWith("ZKRollup: insufficient balance");
    });

    it("user can withdraw via ZK proof using withdrawWithProof", async function () {
      const depositAmount = hre.ethers.parseEther("2.0");
      await rollup.connect(user1).deposit({ value: depositAmount });

      const withdrawAmount = hre.ethers.parseEther("1.0");
      const withdrawalHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("w1"));

      await expect(
        rollup.connect(user2).withdrawWithProof(withdrawAmount, withdrawalHash, "0x", [])
      )
        .to.emit(rollup, "WithdrawalWithProof")
        .withArgs(user2.address, withdrawAmount, withdrawalHash);

      expect(await rollup.executedWithdrawals(withdrawalHash)).to.be.true;
    });

    it("reverts withdrawWithProof on replay attack", async function () {
      await rollup.connect(user1).deposit({ value: hre.ethers.parseEther("2.0") });

      const withdrawAmount = hre.ethers.parseEther("1.0");
      const withdrawalHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("w2"));

      await rollup.connect(user2).withdrawWithProof(withdrawAmount, withdrawalHash, "0x", []);

      await expect(
        rollup.connect(user2).withdrawWithProof(withdrawAmount, withdrawalHash, "0x", [])
      ).to.be.revertedWith("ZKRollup: already executed");
    });

    it("reverts withdrawWithProof if contract balance is insufficient", async function () {
      const withdrawAmount = hre.ethers.parseEther("10.0");
      const withdrawalHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("w3"));

      await expect(
        rollup.connect(user2).withdrawWithProof(withdrawAmount, withdrawalHash, "0x", [])
      ).to.be.revertedWith("ZKRollup: insufficient contract balance");
    });

    it("reverts withdrawWithProof on withdrawalHash publicInput mismatch", async function () {
      await rollup.connect(user1).deposit({ value: hre.ethers.parseEther("2.0") });

      const withdrawAmount = hre.ethers.parseEther("1.0");
      const withdrawalHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("w4"));
      const wrongHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("w5"));

      await expect(
        rollup.connect(user2).withdrawWithProof(withdrawAmount, withdrawalHash, "0x", [wrongHash])
      ).to.be.revertedWith("ZKRollup: withdrawal hash mismatch");
    });
  });
});
