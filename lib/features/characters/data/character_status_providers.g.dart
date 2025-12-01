// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_status_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the character status repository.

@ProviderFor(characterStatusRepository)
const characterStatusRepositoryProvider = CharacterStatusRepositoryProvider._();

/// Provider for the character status repository.

final class CharacterStatusRepositoryProvider extends $FunctionalProvider<
    CharacterStatusRepository,
    CharacterStatusRepository,
    CharacterStatusRepository> with $Provider<CharacterStatusRepository> {
  /// Provider for the character status repository.
  const CharacterStatusRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'characterStatusRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$characterStatusRepositoryHash();

  @$internal
  @override
  $ProviderElement<CharacterStatusRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CharacterStatusRepository create(Ref ref) {
    return characterStatusRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CharacterStatusRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CharacterStatusRepository>(value),
    );
  }
}

String _$characterStatusRepositoryHash() =>
    r'3bc1af7daf7ed8142b074c4db29cf3074e1a23ed';

/// Provides character clones (jump clones + home location).

@ProviderFor(characterClones)
const characterClonesProvider = CharacterClonesFamily._();

/// Provides character clones (jump clones + home location).

final class CharacterClonesProvider extends $FunctionalProvider<
        AsyncValue<CharacterClones>, CharacterClones, FutureOr<CharacterClones>>
    with $FutureModifier<CharacterClones>, $FutureProvider<CharacterClones> {
  /// Provides character clones (jump clones + home location).
  const CharacterClonesProvider._(
      {required CharacterClonesFamily super.from, required int super.argument})
      : super(
          retry: null,
          name: r'characterClonesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$characterClonesHash();

  @override
  String toString() {
    return r'characterClonesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CharacterClones> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<CharacterClones> create(Ref ref) {
    final argument = this.argument as int;
    return characterClones(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterClonesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterClonesHash() => r'7de8d15af7f522ff92c76b602709162d2ee682af';

/// Provides character clones (jump clones + home location).

final class CharacterClonesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CharacterClones>, int> {
  const CharacterClonesFamily._()
      : super(
          retry: null,
          name: r'characterClonesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides character clones (jump clones + home location).

  CharacterClonesProvider call(
    int characterId,
  ) =>
      CharacterClonesProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterClonesProvider';
}

/// Provides character implants with resolved type names.
///
/// Returns a map of implant type ID to name.

@ProviderFor(characterImplants)
const characterImplantsProvider = CharacterImplantsFamily._();

/// Provides character implants with resolved type names.
///
/// Returns a map of implant type ID to name.

final class CharacterImplantsProvider extends $FunctionalProvider<
        AsyncValue<Map<int, String>>,
        Map<int, String>,
        FutureOr<Map<int, String>>>
    with $FutureModifier<Map<int, String>>, $FutureProvider<Map<int, String>> {
  /// Provides character implants with resolved type names.
  ///
  /// Returns a map of implant type ID to name.
  const CharacterImplantsProvider._(
      {required CharacterImplantsFamily super.from,
      required int super.argument})
      : super(
          retry: null,
          name: r'characterImplantsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$characterImplantsHash();

  @override
  String toString() {
    return r'characterImplantsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<int, String>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, String>> create(Ref ref) {
    final argument = this.argument as int;
    return characterImplants(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterImplantsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterImplantsHash() => r'a0af26a8d59b4204fafde6832dd44f3c547c3b6c';

/// Provides character implants with resolved type names.
///
/// Returns a map of implant type ID to name.

final class CharacterImplantsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<int, String>>, int> {
  const CharacterImplantsFamily._()
      : super(
          retry: null,
          name: r'characterImplantsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides character implants with resolved type names.
  ///
  /// Returns a map of implant type ID to name.

  CharacterImplantsProvider call(
    int characterId,
  ) =>
      CharacterImplantsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterImplantsProvider';
}

/// Provides character standings with resolved entity names.

@ProviderFor(characterStandings)
const characterStandingsProvider = CharacterStandingsFamily._();

/// Provides character standings with resolved entity names.

final class CharacterStandingsProvider extends $FunctionalProvider<
        AsyncValue<List<StandingWithName>>,
        List<StandingWithName>,
        FutureOr<List<StandingWithName>>>
    with
        $FutureModifier<List<StandingWithName>>,
        $FutureProvider<List<StandingWithName>> {
  /// Provides character standings with resolved entity names.
  const CharacterStandingsProvider._(
      {required CharacterStandingsFamily super.from,
      required int super.argument})
      : super(
          retry: null,
          name: r'characterStandingsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$characterStandingsHash();

  @override
  String toString() {
    return r'characterStandingsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<StandingWithName>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<StandingWithName>> create(Ref ref) {
    final argument = this.argument as int;
    return characterStandings(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterStandingsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterStandingsHash() =>
    r'7a42340c08cd39dcff716b11250bedfd42645170';

/// Provides character standings with resolved entity names.

final class CharacterStandingsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<StandingWithName>>, int> {
  const CharacterStandingsFamily._()
      : super(
          retry: null,
          name: r'characterStandingsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides character standings with resolved entity names.

  CharacterStandingsProvider call(
    int characterId,
  ) =>
      CharacterStandingsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterStandingsProvider';
}

/// Provides character attributes (already implemented in ESI client).

@ProviderFor(characterAttributes)
const characterAttributesProvider = CharacterAttributesFamily._();

/// Provides character attributes (already implemented in ESI client).

final class CharacterAttributesProvider extends $FunctionalProvider<
        AsyncValue<CharacterAttributes>,
        CharacterAttributes,
        FutureOr<CharacterAttributes>>
    with
        $FutureModifier<CharacterAttributes>,
        $FutureProvider<CharacterAttributes> {
  /// Provides character attributes (already implemented in ESI client).
  const CharacterAttributesProvider._(
      {required CharacterAttributesFamily super.from,
      required int super.argument})
      : super(
          retry: null,
          name: r'characterAttributesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$characterAttributesHash();

  @override
  String toString() {
    return r'characterAttributesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CharacterAttributes> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<CharacterAttributes> create(Ref ref) {
    final argument = this.argument as int;
    return characterAttributes(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterAttributesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterAttributesHash() =>
    r'e617dd588a8b4089ec5322a1011b29ca7cbbcdd6';

/// Provides character attributes (already implemented in ESI client).

final class CharacterAttributesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CharacterAttributes>, int> {
  const CharacterAttributesFamily._()
      : super(
          retry: null,
          name: r'characterAttributesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides character attributes (already implemented in ESI client).

  CharacterAttributesProvider call(
    int characterId,
  ) =>
      CharacterAttributesProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterAttributesProvider';
}

/// Provides aggregated online status including location and ship.

@ProviderFor(characterOnlineStatus)
const characterOnlineStatusProvider = CharacterOnlineStatusFamily._();

/// Provides aggregated online status including location and ship.

final class CharacterOnlineStatusProvider extends $FunctionalProvider<
        AsyncValue<OnlineStatus>, OnlineStatus, FutureOr<OnlineStatus>>
    with $FutureModifier<OnlineStatus>, $FutureProvider<OnlineStatus> {
  /// Provides aggregated online status including location and ship.
  const CharacterOnlineStatusProvider._(
      {required CharacterOnlineStatusFamily super.from,
      required int super.argument})
      : super(
          retry: null,
          name: r'characterOnlineStatusProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$characterOnlineStatusHash();

  @override
  String toString() {
    return r'characterOnlineStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<OnlineStatus> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OnlineStatus> create(Ref ref) {
    final argument = this.argument as int;
    return characterOnlineStatus(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterOnlineStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterOnlineStatusHash() =>
    r'c053b5d4de7d83eebd99ec5428fcef93f6022dce';

/// Provides aggregated online status including location and ship.

final class CharacterOnlineStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<OnlineStatus>, int> {
  const CharacterOnlineStatusFamily._()
      : super(
          retry: null,
          name: r'characterOnlineStatusProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides aggregated online status including location and ship.

  CharacterOnlineStatusProvider call(
    int characterId,
  ) =>
      CharacterOnlineStatusProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterOnlineStatusProvider';
}
