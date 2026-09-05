import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_chat/core/router/app_router.dart';
import 'package:nexus_chat/core/theme/app_theme.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';

void main() {
  testWidgets('Splash shows Folio branding', (tester) async {
    final sessions = SessionsCubit(seed: const []);
    addTearDown(sessions.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: sessions,
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: createAppRouter(),
        ),
      ),
    );

    expect(find.text('Folio'), findsOneWidget);
    expect(find.text('Read smarter'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('No sessions yet'), findsOneWidget);
  });
}
