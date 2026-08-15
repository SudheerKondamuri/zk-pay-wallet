import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../providers/auth_providers.dart';
import '../../../providers/services_providers.dart';
import '../../../shared/pin_dots.dart';
import '../../../shared/pin_numpad.dart';

/// Screen 6 — PIN setup. 6-digit PIN entry with confirmation.
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _firstPin;
  bool _isConfirming = false;
  bool _hasError = false;
  static const _pinLength = 6;

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
  }

  @override
  void dispose() {
    _errorFadeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _hasError = false;
      _errorFadeController.reverse();
    });

    if (_pin.length == _pinLength) {
      _onPinComplete();
    }
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
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
        _errorFadeController.forward(from: 0);
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
              const Spacer(flex: 2),
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
                      'PINs don\'t match. Try again.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),
              // Numpad — no biometric during setup
              PinNumpad(
                onDigit: _addDigit,
                onDelete: _deleteDigit,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
