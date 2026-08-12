import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/services_providers.dart';

/// Screen 7 — Lock screen. PIN entry (with biometric shortcut if enabled).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _hasError = false;
  static const _pinLength = 6;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final storage = ref.read(secureStorageServiceProvider);
    final biometricEnabled = await storage.isBiometricEnabled();
    if (!biometricEnabled) return;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return;

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock ZK Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        _unlock();
      }
    } catch (_) {
      // Biometric not available — fall through to PIN.
    }
  }

  void _addDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _hasError = false;
    });

    if (_pin.length == _pinLength) {
      _verifyPin();
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

  Future<void> _verifyPin() async {
    final storage = ref.read(secureStorageServiceProvider);
    final savedPin = await storage.readPin();

    if (_pin == savedPin) {
      HapticFeedback.mediumImpact();
      _unlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _hasError = true;
      });
    }
  }

  void _unlock() {
    // Load wallet credentials.
    _loadWallet();
    ref.read(authStateProvider.notifier).unlock();
    if (mounted) context.go(AppRoutes.dashboard);
  }

  Future<void> _loadWallet() async {
    final storage = ref.read(secureStorageServiceProvider);
    final wallet = ref.read(walletServiceProvider);
    final pk = await storage.readPrivateKey();
    if (pk != null) wallet.loadCredentials(pk);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.lock_outline,
                color: AppColors.primaryAccent,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Enter your PIN',
                style: Theme.of(context).textTheme.titleLarge,
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
                  'Wrong PIN. Try again.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ],
              const Spacer(),
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
      ['bio', '0', '⌫'],
    ];

    return Column(
      children: digits.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((d) {
              if (d == 'bio') {
                return SizedBox(
                  width: 72,
                  height: 56,
                  child: TextButton(
                    onPressed: _tryBiometric,
                    child: const Icon(
                      Icons.fingerprint,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
                  ),
                );
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
