// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Settings repository provider.

@ProviderFor(settingsRepository)
const settingsRepositoryProvider = SettingsRepositoryProvider._();

/// Settings repository provider.

final class SettingsRepositoryProvider extends $FunctionalProvider<
    SettingsRepository,
    SettingsRepository,
    SettingsRepository> with $Provider<SettingsRepository> {
  /// Settings repository provider.
  const SettingsRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'settingsRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'8b8d87bf14edf6b4a7e2d50f1917265a34e9f56a';

/// Current app settings provider (async).

@ProviderFor(appSettings)
const appSettingsProvider = AppSettingsProvider._();

/// Current app settings provider (async).

final class AppSettingsProvider extends $FunctionalProvider<
        AsyncValue<AppSettings>, AppSettings, FutureOr<AppSettings>>
    with $FutureModifier<AppSettings>, $FutureProvider<AppSettings> {
  /// Current app settings provider (async).
  const AppSettingsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appSettingsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  $FutureProviderElement<AppSettings> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppSettings> create(Ref ref) {
    return appSettings(ref);
  }
}

String _$appSettingsHash() => r'4343a1487addff1a3051d6747c185484ea388e59';

/// Stream of app settings for reactive updates.

@ProviderFor(appSettingsStream)
const appSettingsStreamProvider = AppSettingsStreamProvider._();

/// Stream of app settings for reactive updates.

final class AppSettingsStreamProvider extends $FunctionalProvider<
        AsyncValue<AppSettings>, AppSettings, Stream<AppSettings>>
    with $FutureModifier<AppSettings>, $StreamProvider<AppSettings> {
  /// Stream of app settings for reactive updates.
  const AppSettingsStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appSettingsStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appSettingsStreamHash();

  @$internal
  @override
  $StreamProviderElement<AppSettings> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AppSettings> create(Ref ref) {
    return appSettingsStream(ref);
  }
}

String _$appSettingsStreamHash() => r'bbfc5f2f7ccdd0c54f380a96b60b92498c5df25a';
