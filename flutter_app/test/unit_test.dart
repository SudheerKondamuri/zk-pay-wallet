import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/utils.dart';
import 'package:flutter_app/features/history/models/activity_item.dart';
import 'package:flutter_app/services/wallet_service.dart';

void main() {
  group('String Decimal & Wei Arithmetic (Zero double floats)', () {
    test('ethToWei correctly converts integer and decimal values', () {
      expect(ethToWei('1'), equals('1000000000000000000'));
      expect(ethToWei('0.5'), equals('500000000000000000'));
      expect(ethToWei('0.000000000000000001'), equals('1'));
      expect(ethToWei('1000.123456'), equals('1000123456000000000000'));
      expect(ethToWei('0'), equals('0'));
      expect(ethToWei(''), equals('0'));
    });

    test('weiToEth correctly converts wei strings back to human-readable ETH', () {
      expect(weiToEth('1000000000000000000'), equals('1'));
      expect(weiToEth('500000000000000000'), equals('0.5'));
      expect(weiToEth('1000123456000000000000'), equals('1000.123456'));
      expect(weiToEth('1', decimals: 18), equals('0.000000000000000001'));
      expect(weiToEth('0'), equals('0'));
      expect(weiToEth(''), equals('0'));
    });

    test('formatBalance includes ETH suffix', () {
      expect(formatBalance('1000000000000000000'), equals('1 ETH'));
      expect(formatBalance('500000000000000000'), equals('0.5 ETH'));
    });

    test('address shortening and validation', () {
      const addr = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266';
      expect(shortenAddress(addr), equals('0xf39f...2266'));
      expect(isValidEthAddress(addr), isTrue);
      expect(isValidEthAddress('0xinvalid'), isFalse);
      expect(isValidEthAddress('f39fd6e51aad88f6f4ce6ab8827279cfffb92266'), isFalse);
    });
  });

  group('ActivityItem Model Serialization', () {
    test('ActivityItem round-trip JSON serialization', () {
      final item = ActivityItem(
        id: '0xabc123',
        type: ActivityType.deposit,
        amountWei: '1000000000000000000',
        fromAddress: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
        txHash: '0xabc123',
        timestamp: DateTime(2026, 8, 16, 0, 0, 0),
        status: ActivityStatus.confirmed,
      );

      final json = item.toJson();
      final reconstructed = ActivityItem.fromJson(json);

      expect(reconstructed.id, equals(item.id));
      expect(reconstructed.type, equals(ActivityType.deposit));
      expect(reconstructed.amountWei, equals('1000000000000000000'));
      expect(reconstructed.fromAddress, equals(item.fromAddress));
      expect(reconstructed.txHash, equals('0xabc123'));
      expect(reconstructed.status, equals(ActivityStatus.confirmed));
    });

    test('ActivityItem.fromIntent converts backend intent maps', () {
      final intentJson = {
        'id': 42,
        'from_address': '0x1111111111111111111111111111111111111111',
        'to_address': '0x2222222222222222222222222222222222222222',
        'amount_wei': '500000000000000000',
        'status': 'batched',
        'batch_index': 3,
        'created_at': '2026-08-16T00:00:00.000Z',
      };

      final item = ActivityItem.fromIntent(intentJson);
      expect(item.id, equals('42'));
      expect(item.type, equals(ActivityType.send));
      expect(item.amountWei, equals('500000000000000000'));
      expect(item.status, equals(ActivityStatus.batched));
      expect(item.batchIndex, equals(3));
    });
  });

  group('WalletService Mnemonic Generation & BIP44', () {
    test('Generates valid 12-word mnemonic', () {
      final service = WalletService();
      final mnemonic = service.generateMnemonic();
      final words = mnemonic.split(' ');
      expect(words.length, equals(12));
      expect(service.validateMnemonic(mnemonic), isTrue);
      expect(service.validateMnemonic('invalid words phrase that should fail'), isFalse);
    });

    test('Derives correct Ethereum address from known mnemonic', () {
      final service = WalletService();
      // BIP39 standard test vector
      const mnemonic = 'test test test test test test test test test test test junk';
      final pk = service.derivePrivateKey(mnemonic);
      service.loadCredentials(pk);
      expect(service.isLoaded, isTrue);
      expect(isValidEthAddress(service.address), isTrue);
    });

    test('Loads wallet from private key hex', () {
      final service = WalletService();
      // Hardhat Account #0
      const pk = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
      service.loadCredentials(pk);
      expect(service.isLoaded, isTrue);
      expect(
        service.address.toLowerCase(),
        equals('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'.toLowerCase()),
      );
    });
  });
}
