import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants.dart';
import '../../../app/theme.dart';

import '../../../providers/services_providers.dart';
import '../providers/wallet_providers.dart';
import '../../../shared/app_bottom_sheet.dart';
import '../widgets/deposit_sheet.dart';
import '../../../shared/flat_card.dart';

/// Screen 9 — Receive. QR code of the user's address + copy button.
/// Also hosts the Deposit bottom sheet trigger.
class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.read(walletServiceProvider);
    final address = wallet.address;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Share your address to receive ETH',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              // QR code
              Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: address,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: Color(0xFF0F1512),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF0F1512),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Address card
              FlatCard(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: address));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied')),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 13,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
              const Spacer(),
              // Deposit from Receive screen
              TextButton.icon(
                onPressed: () async {
                  final tx = await AppBottomSheet.show(
                    context: context,
                    child: const DepositSheet(),
                  );
                  if (tx != null) {
                    ref.read(onChainDepositProvider(address).notifier).refresh();
                    ref.read(l2BalanceProvider(address).notifier).refresh();
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Deposit from L1'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryAccent,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
