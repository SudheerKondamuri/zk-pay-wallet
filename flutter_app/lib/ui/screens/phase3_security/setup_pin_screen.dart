import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/services_providers.dart';


/// Screen 6 — PIN setup. 6-digit PIN entry with confirmation.
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  String _pin = '';
  String? _firstPin;
  bool _isConfirming = false;
  bool _hasError = false;
  static const _pinLength = 6;

  void _addDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _hasError = false;
    });

    if (_pin.length == _pinLength) {
      _onPinComplete();
    }
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _hasError = false;
    });
  }

  Future<void> _onPinComplete() async {
    if (!_isConfirming) {
      // First entry — store and ask to confirm.
      _firstPin = _pin;
      setState(() {
        _pin = '';
        _isConfirming = true;
      });
    } else {
      // Confirm — check match.
      if (_pin == _firstPin) {
        HapticFeedback.mediumImpact();
        final storage = ref.read(secureStorageServiceProvider);
        await storage.savePin(_pin);
        ref.read(authStateProvider.notifier).unlock();

        if (mounted) context.go(AppRoutes.dashboard);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Create a 6-digit PIN',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isConfirming
                    ? 'Enter the same PIN again'
                    : 'This PIN secures access to your wallet',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: AppDuration.micro,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? AppColors.danger
                          : filled
                              ? AppColors.primaryAccent
                              : Colors.transparent,
                      border: Border.all(
                        color: _hasError
                            ? AppColors.danger
                            : AppColors.primaryAccent,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              if (_hasError) ...[
                const SizedBox(height: AppSpacing.base),
                Text(
                  'PINs don\'t match. Try again.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ],
              const Spacer(),
              // Numpad
              _buildNumpad(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: digits.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((d) {
              if (d.isEmpty) {
                return const SizedBox(width: 72, height: 56);
              }
              if (d == '⌫') {
                return SizedBox(
                  width: 72,
                  height: 56,
                  child: TextButton(
                    onPressed: _deleteDigit,
                    child: const Icon(
                      Icons.backspace_outlined,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                );
              }
              return SizedBox(
                width: 72,
                height: 56,
                child: TextButton(
                  onPressed: () => _addDigit(d),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    d,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
