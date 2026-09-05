import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexus_chat/core/storage/local_store.dart';
import 'package:nexus_chat/features/settings/domain/folio_settings.dart';

class SettingsCubit extends Cubit<FolioSettings> {
  SettingsCubit({required LocalStore store})
      : _store = store,
        super(store.loadSettings());

  final LocalStore _store;

  Future<void> setFormat(String format) async {
    emit(state.copyWith(format: format));
    await _store.saveSettings(state);
  }

  Future<void> setLength(String length) async {
    emit(state.copyWith(length: length));
    await _store.saveSettings(state);
  }

  Future<void> setChatScope(String chatScope) async {
    emit(state.copyWith(chatScope: chatScope));
    await _store.saveSettings(state);
  }

  Future<void> setApiKey(String apiKey) async {
    emit(state.copyWith(apiKey: apiKey.trim()));
    await _store.saveSettings(state);
  }

  Future<void> setCustomPrompt(String prompt) async {
    emit(state.copyWith(customPrompt: prompt));
    await _store.saveSettings(state);
  }
}
