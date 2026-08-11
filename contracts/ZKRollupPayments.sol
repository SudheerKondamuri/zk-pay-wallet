// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IZKVerifier.sol";

contract ZKRollupPayments {
    // Custom Errors for maximum gas efficiency
    error NotOwner();
    error NotRelayer();
    error InvalidProof();
    error InsufficientBalance();
    error TransferFailed();
    error ZeroAddress();
    error AmountZero();
    error AlreadyPaused();
    error NotPaused();
    error ContractPaused();
    error ReentrantCall();
    error InvalidStateRoot();
    error EmptyBatch();
    error AlreadyExecuted();
    error InsufficientContractBalance();

    struct BatchRecord {
        bytes32 oldStateRoot;
        bytes32 newStateRoot;
        uint256 txCount;
        bytes32 batchHash;
        uint256 committedAt;
        address relayer;
    }

    // verifier is immutable to eliminate SLOAD gas costs
    address public immutable verifier;
    bytes32 public currentStateRoot;
    uint256 public batchCount;
    mapping(uint256 => BatchRecord) public batches;
    mapping(address => uint256) public deposits;
    mapping(bytes32 => bool) public executedWithdrawals;

    address public owner;
    bool public paused;
    mapping(address => bool) private _relayers;

    // Reentrancy guard state
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // Core events
    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event BatchCommitted(uint256 indexed batchIndex, bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, address relayer);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawalWithProof(address indexed user, uint256 amount, bytes32 indexed withdrawalHash);

    // Administrative & Security events
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event Paused(address account);
    event Unpaused(address account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _verifier) {
        if (_verifier == address(0)) revert ZeroAddress();
        verifier = _verifier;
        currentStateRoot = bytes32(0);
        owner = msg.sender;
        _relayers[msg.sender] = true;
        _status = _NOT_ENTERED;
        emit RelayerAdded(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function addRelayer(address relayer) external onlyOwner {
        if (relayer == address(0)) revert ZeroAddress();
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
        if (msg.value == 0) revert AmountZero();
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
        if (!_relayers[msg.sender]) revert NotRelayer();
        if (!IZKVerifier(verifier).verifyProof(proof, publicInputs)) revert InvalidProof();
        if (newStateRoot == bytes32(0)) revert InvalidStateRoot();
        if (txCount == 0) revert EmptyBatch();

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
        if (amount == 0) revert AmountZero();
        uint256 userBalance = deposits[msg.sender];
        if (userBalance < amount) revert InsufficientBalance();
        
        unchecked {
            deposits[msg.sender] = userBalance - amount;
        }

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function withdrawWithProof(
        uint256 amount,
        bytes32 withdrawalHash,
        bytes calldata proof,
        uint256[] calldata publicInputs
    ) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();
        if (executedWithdrawals[withdrawalHash]) revert AlreadyExecuted();
        if (address(this).balance < amount) revert InsufficientContractBalance();
        if (!IZKVerifier(verifier).verifyProof(proof, publicInputs)) revert InvalidProof();

        executedWithdrawals[withdrawalHash] = true;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
        emit WithdrawalWithProof(msg.sender, amount, withdrawalHash);
    }
}
