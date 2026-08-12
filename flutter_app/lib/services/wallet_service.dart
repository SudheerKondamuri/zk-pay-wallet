import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import '../core/env.dart';

/// Owns the web3dart client and private key. Builds/signs deposit()
/// and withdraw() transactions, and reads on-chain deposits(address).
/// Never logs or exposes the key outside this class.
class WalletService {
  Web3Client? _web3;
  EthPrivateKey? _credentials;
  String? _contractAddress;

  Web3Client get web3 {
    _web3 ??= Web3Client(Env.rpcUrl, http.Client());
    return _web3!;
  }

  /// Reinitialize web3 client (e.g. after RPC URL change in settings).
  void resetWeb3() {
    _web3?.dispose();
    _web3 = null;
  }

  /// Derive private key from mnemonic using BIP44 path m/44'/60'/0'/0/0.
  String derivePrivateKey(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/60'/0'/0/0");
    return HEX.encode(child.privateKey!);
  }

  /// Load credentials from a hex private key string.
  void loadCredentials(String privateKeyHex) {
    final key = privateKeyHex.startsWith('0x')
        ? privateKeyHex.substring(2)
        : privateKeyHex;
    _credentials = EthPrivateKey(Uint8List.fromList(HEX.decode(key)));
  }

  /// Get the wallet's Ethereum address as a checksummed hex string.
  String get address {
    if (_credentials == null) throw StateError('Wallet not loaded');
    return _credentials!.address.hexEip55;
  }

  /// Check if credentials are loaded.
  bool get isLoaded => _credentials != null;

  /// Set the contract address (fetched from GET /state).
  void setContractAddress(String addr) => _contractAddress = addr;

  // --- Contract ABI fragments ---

  static final _depositFunction = ContractFunction(
    'deposit',
    [],
  );

  static final _withdrawFunction = ContractFunction(
    'withdraw',
    [FunctionParameter('amount', UintType(length: 256))],
  );

  static final _depositsFunction = ContractFunction(
    'deposits',
    [FunctionParameter('', AddressType())],
  );

  /// Read on-chain deposits(address) — returns Wei as decimal string.
  /// This is the L1 withdrawable ceiling, not the L2 balance.
  Future<String> getOnChainDeposit(String userAddress) async {
    if (_contractAddress == null) throw StateError('Contract address not set');

    final contract = DeployedContract(
      ContractAbi('ZKRollupPayments', [_depositsFunction], []),
      EthereumAddress.fromHex(_contractAddress!),
    );

    final result = await web3.call(
      contract: contract,
      function: _depositsFunction,
      params: [EthereumAddress.fromHex(userAddress)],
    );

    final balance = result.first as BigInt;
    return balance.toString();
  }

  /// Send ETH to the contract's deposit() function — signed locally.
  Future<String> deposit(String amountWei) async {
    if (_credentials == null) throw StateError('Wallet not loaded');
    if (_contractAddress == null) throw StateError('Contract address not set');

    final contract = DeployedContract(
      ContractAbi('ZKRollupPayments', [_depositFunction], []),
      EthereumAddress.fromHex(_contractAddress!),
    );

    final txHash = await web3.sendTransaction(
      _credentials!,
      Transaction.callContract(
        contract: contract,
        function: _depositFunction,
        parameters: [],
        value: EtherAmount.inWei(BigInt.parse(amountWei)),
      ),
      chainId: Env.chainId,
    );

    return txHash;
  }

  /// Call withdraw(uint256 amount) — signed locally.
  /// Amount is capped at on-chain deposits(address) by the caller.
  Future<String> withdraw(String amountWei) async {
    if (_credentials == null) throw StateError('Wallet not loaded');
    if (_contractAddress == null) throw StateError('Contract address not set');

    final contract = DeployedContract(
      ContractAbi('ZKRollupPayments', [_withdrawFunction], []),
      EthereumAddress.fromHex(_contractAddress!),
    );

    final txHash = await web3.sendTransaction(
      _credentials!,
      Transaction.callContract(
        contract: contract,
        function: _withdrawFunction,
        parameters: [BigInt.parse(amountWei)],
      ),
      chainId: Env.chainId,
    );

    return txHash;
  }

  /// Generate a new 12-word mnemonic.
  String generateMnemonic() => bip39.generateMnemonic();

  /// Validate a mnemonic phrase.
  bool validateMnemonic(String mnemonic) => bip39.validateMnemonic(mnemonic);

  void dispose() {
    _web3?.dispose();
  }
}
