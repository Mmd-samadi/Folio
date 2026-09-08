import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/router/app_router.dart';
import 'package:nexus_chat/core/storage/local_store.dart';
import 'package:nexus_chat/core/theme/app_theme.dart';
import 'package:nexus_chat/features/ai/data/on_device_model_catalog_service.dart';
import 'package:nexus_chat/features/books/presentation/cubit/books_cubit.dart';
import 'package:nexus_chat/features/reader/presentation/cubit/summarize_job_cubit.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:pdfrx/pdfrx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  await dotenv.load(fileName: '.env');

  const hfToken = String.fromEnvironment('HUGGINGFACE_TOKEN');
  await FlutterGemma.initialize(
    huggingFaceToken: hfToken.isNotEmpty ? hfToken : null,
    inferenceEngines: const [
      LiteRtLmEngine(),
      MediaPipeEngine(),
    ],
  );

  await OnDeviceModelCatalogService.instance.ensureLoaded();

  final store = await LocalStore.open();
  runApp(FolioApp(store: store));
}

class FolioApp extends StatefulWidget {
  const FolioApp({super.key, required this.store});

  final LocalStore store;

  @override
  State<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends State<FolioApp> {
  late final SessionsCubit _sessionsCubit;
  late final BooksCubit _booksCubit;
  late final SettingsCubit _settingsCubit;
  late final SummarizeJobCubit _summarizeJobCubit;
  late final router = createAppRouter();

  @override
  void initState() {
    super.initState();
    _sessionsCubit = SessionsCubit(store: widget.store);
    _booksCubit = BooksCubit(store: widget.store, sessions: _sessionsCubit);
    _settingsCubit = SettingsCubit(store: widget.store);
    _summarizeJobCubit = SummarizeJobCubit();
    _hydrate();
  }

  Future<void> _hydrate() async {
    await _sessionsCubit.hydrate();
    await _booksCubit.hydrate();
  }

  @override
  void dispose() {
    _summarizeJobCubit.close();
    _booksCubit.close();
    _sessionsCubit.close();
    _settingsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sessionsCubit),
        BlocProvider.value(value: _booksCubit),
        BlocProvider.value(value: _settingsCubit),
        BlocProvider.value(value: _summarizeJobCubit),
        RepositoryProvider.value(value: widget.store),
      ],
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
