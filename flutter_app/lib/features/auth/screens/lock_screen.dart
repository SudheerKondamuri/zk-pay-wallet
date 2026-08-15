import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../providers/auth_providers.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/pin_dots.dart';
import '../../../shared/pin_numpad.dart';

/// Screen 7 — Lock screen. PIN entry (with biometric shortcut if enabled).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _hasError = false;
  static const _pinLength = 6;
  final _localAuth = LocalAuthentication();

  late final AnimationController _errorFadeController;
  late final Animation<double> _errorFadeAnimation;

  @override
  void initState() {
    super.initState();
    _errorFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _errorFadeAnimation = CurvedAnimation(
      parent: _errorFadeController,
      curve: Curves.easeIn,
    );
    _tryBiometric();
  }

  @override
  void dispose() {
    _errorFadeController.dispose();
    super.dispose();
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
        await _unlock();
      }
    } catch (_) {
      // Biometric not available — fall through to PIN.
    }
  }

  void _addDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _hasError = false;
      _errorFadeController.reverse();
    });

    if (_pin.length == _pinLength) {
      _verifyPin();
    }
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
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
      await _unlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _hasError = true;
      });
      _errorFadeController.forward(from: 0);
    }
  }

  Future<void> _unlock() async {
    // Load wallet credentials.
    await _loadWallet();
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
              const Spacer(flex: 2),
              // Shield icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryAccent.withValues(alpha: 0.18),
                      AppColors.primaryAccent.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primaryAccent,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Enter your PIN',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              // PIN dots
              PinDots(
                length: _pinLength,
                filledCount: _pin.length,
                hasError: _hasError,
              ),
              // Error message with fade
              SizedBox(
                height: 40,
                child: FadeTransition(
                  opacity: _errorFadeAnimation,
                  child: Center(
                    child: Text(
                      'Wrong PIN. Try again.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),
              // Numpad
              PinNumpad(
                onDigit: _addDigit,
                onDelete: _deleteDigit,
                onBiometric: _tryBiometric,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
