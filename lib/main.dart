import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:folio/core/constants/app_constants.dart';
import 'package:folio/core/router/app_router.dart';
import 'package:folio/core/storage/local_store.dart';
import 'package:folio/core/theme/app_theme.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/core/theme/theme_cubit.dart';
import 'package:folio/features/ai/data/local_gemma_service.dart';
import 'package:folio/features/ai/data/on_device_model_catalog_service.dart';
import 'package:folio/features/ai/presentation/cubit/on_device_load_cubit.dart';
import 'package:folio/features/ai/presentation/widgets/on_device_resource_banner.dart';
import 'package:folio/features/books/presentation/cubit/books_cubit.dart';
import 'package:folio/features/reader/presentation/cubit/summarize_job_cubit.dart';
import 'package:folio/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:folio/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:pdfrx/pdfrx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  await dotenv.load(fileName: '.env');

  const hfToken = String.fromEnvironment('HUGGINGFACE_TOKEN');
  await FlutterGemma.initialize(
    huggingFaceToken: hfToken.isNotEmpty ? hfToken : null,
    inferenceEngines: const [LiteRtLmEngine(), MediaPipeEngine()],
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
  late final OnDeviceLoadCubit _onDeviceLoadCubit;
  late final ThemeCubit _themeCubit;
  late final router = createAppRouter();

  @override
  void initState() {
    super.initState();
    _sessionsCubit = SessionsCubit(store: widget.store);
    _booksCubit = BooksCubit(store: widget.store, sessions: _sessionsCubit);
    _settingsCubit = SettingsCubit(store: widget.store);
    _summarizeJobCubit = SummarizeJobCubit();
    _onDeviceLoadCubit = OnDeviceLoadCubit();
    _themeCubit = ThemeCubit();
    LocalGemmaService.instance.attachLoadCubit(_onDeviceLoadCubit);
    _hydrate();
  }

  Future<void> _hydrate() async {
    await _sessionsCubit.hydrate();
    await _booksCubit.hydrate();
    await _settingsCubit.hydrate();
    _themeCubit.setMode(_settingsCubit.state.themeMode);
  }

  @override
  void dispose() {
    _onDeviceLoadCubit.close();
    _themeCubit.close();
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
        BlocProvider.value(value: _onDeviceLoadCubit),
        BlocProvider.value(value: _themeCubit),
        RepositoryProvider.value(value: widget.store),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: AppConstants.appTitle,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: router,
            builder: (context, child) {
              FolioColors.bind(Theme.of(context));
              return Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const OnDeviceResourceBanner(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
