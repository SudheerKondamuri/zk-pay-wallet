import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

class ZKVaultApp extends ConsumerWidget {
  const ZKVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildRouter(ref);

    return MaterialApp.router(
      title: 'ZK Vault',
      debugShowCheckedModeBanner: false,
      theme: buildVerdigrisTheme(),
      routerConfig: router,
    );
  }
}
