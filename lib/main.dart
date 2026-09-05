import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/router/app_router.dart';
import 'package:nexus_chat/core/theme/app_theme.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:pdfrx/pdfrx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  await dotenv.load(fileName: '.env');
  runApp(const FolioApp());
}

class FolioApp extends StatefulWidget {
  const FolioApp({super.key});

  @override
  State<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends State<FolioApp> {
  late final SessionsCubit _sessionsCubit;
  late final router = createAppRouter();

  @override
  void initState() {
    super.initState();
    _sessionsCubit = SessionsCubit();
  }

  @override
  void dispose() {
    _sessionsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _sessionsCubit,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appTitle,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
