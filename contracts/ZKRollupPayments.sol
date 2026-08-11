// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IZKVerifier.sol";

contract ZKRollupPayments {
    struct BatchRecord {
        bytes32 oldStateRoot;
        bytes32 newStateRoot;
        uint256 txCount;
        bytes32 batchHash;
        uint256 committedAt;
        address relayer;
    }

    address public immutable verifier;
    bytes32 public currentStateRoot;
    uint256 public batchCount;
    mapping(uint256 => BatchRecord) public batches;
    mapping(address => uint256) public deposits;
    mapping(bytes32 => bool) public executedWithdrawals;

    address public owner;
    bool public paused;
    mapping(address => bool) private _relayers;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event BatchCommitted(uint256 indexed batchIndex, bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, address relayer);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawalWithProof(address indexed user, uint256 amount, bytes32 indexed withdrawalHash);

    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event Paused(address account);
    event Unpaused(address account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "ZKRollup: not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "ZKRollup: paused");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ZKRollup: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _verifier) {
        require(_verifier != address(0), "ZKRollup: zero address");
        verifier = _verifier;
        currentStateRoot = bytes32(0);
        owner = msg.sender;
        _relayers[msg.sender] = true;
        _status = _NOT_ENTERED;
        emit RelayerAdded(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZKRollup: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        require(!paused, "ZKRollup: already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        require(paused, "ZKRollup: not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function addRelayer(address relayer) external onlyOwner {
        require(relayer != address(0), "ZKRollup: zero address");
        _relayers[relayer] = true;
        emit RelayerAdded(relayer);
    }

    function removeRelayer(address relayer) external onlyOwner {
        _relayers[relayer] = false;
        emit RelayerRemoved(relayer);
    }

    function isRelayer(address relayer) external view returns (bool) {
        return _relayers[relayer];
    }

    function deposit() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "ZKRollup: amount zero");
        uint256 newBalance = deposits[msg.sender] + msg.value;
        deposits[msg.sender] = newBalance;
        emit Deposited(msg.sender, msg.value, newBalance);
    }

    function commitBatch(
        bytes32 newStateRoot,
        bytes32 batchHash,
        uint256 txCount,
        bytes calldata proof,
        uint256[] calldata publicInputs
    ) external whenNotPaused nonReentrant {
        require(_relayers[msg.sender], "ZKRollup: not relayer");
        require(
            IZKVerifier(verifier).verifyProof(proof, publicInputs),
            "ZKRollup: invalid proof"
        );
        require(newStateRoot != bytes32(0), "ZKRollup: invalid state root");
        require(txCount > 0, "ZKRollup: empty batch");

        bytes32 oldStateRoot = currentStateRoot;
        currentStateRoot = newStateRoot;

        uint256 currentBatch = batchCount;
        batches[currentBatch] = BatchRecord({
            oldStateRoot: oldStateRoot,
            newStateRoot: newStateRoot,
            txCount: txCount,
            batchHash: batchHash,
            committedAt: block.timestamp,
            relayer: msg.sender
        });

        emit BatchCommitted(currentBatch, newStateRoot, batchHash, txCount, msg.sender);
        
        unchecked {
            batchCount = currentBatch + 1;
        }
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "ZKRollup: amount zero");
        uint256 userBalance = deposits[msg.sender];
        require(userBalance >= amount, "ZKRollup: insufficient balance");
        
        unchecked {
            deposits[msg.sender] = userBalance - amount;
        }

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ZKRollup: transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function withdrawWithProof(
        uint256 amount,
        bytes32 withdrawalHash,
        bytes calldata proof,
        uint256[] calldata publicInputs
    ) external whenNotPaused nonReentrant {
        require(amount > 0, "ZKRollup: amount zero");
        require(!executedWithdrawals[withdrawalHash], "ZKRollup: already executed");
        require(address(this).balance >= amount, "ZKRollup: insufficient contract balance");
        require(
            IZKVerifier(verifier).verifyProof(proof, publicInputs),
            "ZKRollup: invalid proof"
        );

        executedWithdrawals[withdrawalHash] = true;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ZKRollup: transfer failed");

        emit Withdrawn(msg.sender, amount);
        emit WithdrawalWithProof(msg.sender, amount, withdrawalHash);
    }
}