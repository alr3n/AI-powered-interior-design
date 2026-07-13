import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

/// Persisted lightweight settings (theme, currency, budget tier).
class SettingsNotifier extends Notifier<AppSettings> {
  static const _kTheme = 'themeMode';
  static const _kTier = 'budgetTier';
  static const _kCurrency = 'currency';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == prefs.getString(_kTheme),
          orElse: () => ThemeMode.system),
      budgetTier: prefs.getString(_kTier) ?? 'medium',
      currency: prefs.getString(_kCurrency) ?? AppConstants.defaultCurrency,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    (await SharedPreferences.getInstance()).setString(_kTheme, mode.name);
  }

  Future<void> setBudgetTier(String tier) async {
    state = state.copyWith(budgetTier: tier);
    (await SharedPreferences.getInstance()).setString(_kTier, tier);
  }
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.budgetTier = 'medium',
    this.currency = AppConstants.defaultCurrency,
  });

  final ThemeMode themeMode;
  final String budgetTier;
  final String currency;

  AppSettings copyWith(
          {ThemeMode? themeMode, String? budgetTier, String? currency}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        budgetTier: budgetTier ?? this.budgetTier,
        currency: currency ?? this.currency,
      );
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final themeModeProvider =
    Provider<ThemeMode>((ref) => ref.watch(settingsProvider).themeMode);
