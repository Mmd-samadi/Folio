import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/theme/app_theme.dart';
import 'package:nexus_chat/core/theme/theme_cubit.dart';
import 'package:nexus_chat/features/chat/presentation/pages/chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const NexusChatApp());
}

class NexusChatApp extends StatelessWidget {
  const NexusChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeCubit(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConstants.appTitle,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const ChatPage(),
          );
        },
      ),
    );
  }
}
