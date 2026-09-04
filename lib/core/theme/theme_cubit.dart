import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  void toggleTheme() {
    switch (state) {
      case ThemeMode.light:
        emit(ThemeMode.dark);
      case ThemeMode.dark:
        emit(ThemeMode.light);
      case ThemeMode.system:
        emit(ThemeMode.dark);
    }
  }
}
