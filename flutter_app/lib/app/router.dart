import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/onboarding/screens/welcome_screen.dart';
import '../features/onboarding/screens/seed_generation_screen.dart';
import '../features/onboarding/screens/seed_verification_screen.dart';
import '../features/onboarding/screens/import_wallet_screen.dart';
import '../features/onboarding/screens/import_private_key_screen.dart';
import '../features/auth/screens/setup_pin_screen.dart';
import '../features/auth/screens/lock_screen.dart';
import '../features/wallet/screens/dashboard_screen.dart';
import '../features/wallet/screens/receive_screen.dart';
import '../features/wallet/screens/send_screen.dart';
import '../features/wallet/screens/withdraw_screen.dart';
import '../features/wallet/screens/transaction_result_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/history/screens/intent_detail_screen.dart';
import '../features/history/screens/batch_explorer_screen.dart';
import '../features/history/screens/batch_detail_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/network_config_screen.dart';
import '../features/settings/screens/address_book_screen.dart';

// Route path constants
abstract final class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String seedGeneration = '/seed-generation';
  static const String seedVerification = '/seed-verification';
  static const String importWallet = '/import-wallet';
  static const String importPrivateKey = '/import-private-key';
  static const String setupPin = '/setup-pin';
  static const String lock = '/lock';
  static const String dashboard = '/dashboard';
  static const String receive = '/receive';
  static const String send = '/send';
  static const String withdraw = '/withdraw';
  static const String transactionResult = '/transaction-result';
  static const String history = '/history';
  static const String intentDetail = '/intent-detail';
  static const String batchExplorer = '/batches';
  static const String batchDetail = '/batch-detail';
  static const String settings = '/settings';
  static const String networkConfig = '/settings/network';
  static const String addressBook = '/settings/address-book';
}

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLocked = authState.isLocked;
      final hasWallet = authState.hasWallet;
      final currentPath = state.matchedLocation;

      // Onboarding paths — always accessible
      const onboardingPaths = [
        AppRoutes.splash,
        AppRoutes.welcome,
        AppRoutes.seedGeneration,
        AppRoutes.seedVerification,
        AppRoutes.importWallet,
        AppRoutes.importPrivateKey,
        AppRoutes.setupPin,
      ];

      // If no wallet and not on onboarding, redirect to welcome
      if (!hasWallet && !onboardingPaths.contains(currentPath)) {
        return AppRoutes.welcome;
      }

      // If wallet exists but locked, redirect to lock screen
      if (hasWallet &&
          isLocked &&
          currentPath != AppRoutes.lock &&
          currentPath != AppRoutes.setupPin) {
        return AppRoutes.lock;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.seedGeneration,
        builder: (context, state) => const SeedGenerationScreen(),
      ),
      GoRoute(
        path: AppRoutes.seedVerification,
        builder: (context, state) {
          final mnemonic = state.extra as String;
          return SeedVerificationScreen(mnemonic: mnemonic);
        },
      ),
      GoRoute(
        path: AppRoutes.importWallet,
        builder: (context, state) => const ImportWalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.importPrivateKey,
        builder: (context, state) => const ImportPrivateKeyScreen(),
      ),
      GoRoute(
        path: AppRoutes.setupPin,
        builder: (context, state) => const SetupPinScreen(),
      ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.receive,
        builder: (context, state) => const ReceiveScreen(),
      ),
      GoRoute(
        path: AppRoutes.send,
        builder: (context, state) => const SendScreen(),
      ),
      GoRoute(
        path: AppRoutes.withdraw,
        builder: (context, state) => const WithdrawScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactionResult,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TransactionResultScreen(
            success: extra['success'] as bool,
            type: extra['type'] as String,
            amount: extra['amount'] as String,
            toAddress: extra['to'] as String?,
            txHash: extra['txHash'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.intentDetail,
        builder: (context, state) {
          final intent = state.extra as Map<String, dynamic>;
          return IntentDetailScreen(intent: intent);
        },
      ),
      GoRoute(
        path: AppRoutes.batchExplorer,
        builder: (context, state) => const BatchExplorerScreen(),
      ),
      GoRoute(
        path: AppRoutes.batchDetail,
        builder: (context, state) {
          final batchIndex = state.extra as int;
          return BatchDetailScreen(batchIndex: batchIndex);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.networkConfig,
        builder: (context, state) => const NetworkConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.addressBook,
        builder: (context, state) => const AddressBookScreen(),
      ),
    ],
  );
}
