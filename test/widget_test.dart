import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/router/app_router.dart';
import 'package:folio/core/storage/local_store.dart';
import 'package:folio/core/theme/app_theme.dart';
import 'package:folio/features/books/presentation/cubit/books_cubit.dart';
import 'package:folio/features/reader/presentation/cubit/summarize_job_cubit.dart';
import 'package:folio/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:folio/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Splash shows Folio branding', (tester) async {
    SharedPreferences.setMockInitialValues({
      'folio_sessions_v1': '[]',
      'folio_books_v1': '[]',
    });
    final store = await LocalStore.open();
    final sessions = SessionsCubit(store: store, seed: const []);
    final books = BooksCubit(store: store, sessions: sessions, seed: const []);
    final settings = SettingsCubit(store: store);
    final summarizeJob = SummarizeJobCubit();
    addTearDown(books.close);
    addTearDown(sessions.close);
    addTearDown(settings.close);
    addTearDown(summarizeJob.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sessions),
          BlocProvider.value(value: books),
          BlocProvider.value(value: settings),
          BlocProvider.value(value: summarizeJob),
          RepositoryProvider.value(value: store),
        ],
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

    expect(find.text('No books yet'), findsOneWidget);
  });
}
