import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../providers/address_book_provider.dart';

import '../../shared/app_text_field.dart';
import '../../shared/empty_state.dart';
import '../../shared/flat_card.dart';

/// Screen 20 — Address Book. CRUD list of labeled addresses.
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(addressBookProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: entries.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.contacts_outlined,
              title: 'No contacts yet',
              subtitle: 'Add frequent addresses for quick access.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final entry = list[index];
              return Dismissible(
                key: ValueKey(entry.address),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  color: AppColors.danger.withValues(alpha: 0.2),
                  child: const Icon(Icons.delete, color: AppColors.danger),
                ),
                onDismissed: (_) {
                  ref.read(addressBookProvider.notifier).remove(index);
                },
                child: FlatCard(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.address));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${entry.name} copied')),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryAccent.withValues(alpha: 0.1),
                        ),
                        child: Center(
                          child: Text(
                            entry.name.isNotEmpty
                                ? entry.name[0].toUpperCase()
                                : '?',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.primaryAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.name,
                                style:
                                    Theme.of(context).textTheme.labelLarge),
                            Text(
                              shortenAddress(entry.address),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontFamily: 'SpaceGrotesk'),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.copy,
                          size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Error loading contacts',
          subtitle: 'Try reopening the app.',
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final labelCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceFlat,
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: labelCtrl,
              labelText: 'Label',
              hintText: 'e.g. Alice',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: addressCtrl,
              labelText: 'Address',
              hintText: '0x...',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              final address = addressCtrl.text.trim();
              if (label.isNotEmpty && isValidEthAddress(address)) {
                ref.read(addressBookProvider.notifier).add(
                      AddressBookEntry(name: label, address: address),
                    );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
