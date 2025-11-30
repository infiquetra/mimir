// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$settingsRepositoryHash() =>
    r'9134e8f83b21eab1b79ad05bf930d7d99a51da73';

/// Settings repository provider.
///
/// Copied from [settingsRepository].
@ProviderFor(settingsRepository)
final settingsRepositoryProvider =
    AutoDisposeProvider<SettingsRepository>.internal(
  settingsRepository,
  name: r'settingsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$settingsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SettingsRepositoryRef = AutoDisposeProviderRef<SettingsRepository>;
String _$appSettingsHash() => r'73ebbd2a9940eb908814e85ec5cad9866886d71e';

/// Current app settings provider (async).
///
/// Copied from [appSettings].
@ProviderFor(appSettings)
final appSettingsProvider = AutoDisposeFutureProvider<AppSettings>.internal(
  appSettings,
  name: r'appSettingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppSettingsRef = AutoDisposeFutureProviderRef<AppSettings>;
String _$appSettingsStreamHash() => r'0738fee81863b32299abc47899332f9d15db3912';

/// Stream of app settings for reactive updates.
///
/// Copied from [appSettingsStream].
@ProviderFor(appSettingsStream)
final appSettingsStreamProvider =
    AutoDisposeStreamProvider<AppSettings>.internal(
  appSettingsStream,
  name: r'appSettingsStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appSettingsStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppSettingsStreamRef = AutoDisposeStreamProviderRef<AppSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
