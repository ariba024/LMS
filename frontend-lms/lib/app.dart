import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'core/theme/scroll_behavior.dart';

class ArrestoApp extends ConsumerWidget {
  const ArrestoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Arresto LMS',
      theme: buildArrestoTheme(),
      scrollBehavior: const ArrestoScrollBehavior(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
