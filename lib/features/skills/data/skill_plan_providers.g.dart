// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_plan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for skill plan mutations (create, update, delete).
///
/// Handles all skill plan CRUD operations with proper error handling
/// and logging.

@ProviderFor(SkillPlanNotifier)
const skillPlanProvider = SkillPlanNotifierProvider._();

/// Notifier for skill plan mutations (create, update, delete).
///
/// Handles all skill plan CRUD operations with proper error handling
/// and logging.
final class SkillPlanNotifierProvider
    extends $NotifierProvider<SkillPlanNotifier, AsyncValue<void>> {
  /// Notifier for skill plan mutations (create, update, delete).
  ///
  /// Handles all skill plan CRUD operations with proper error handling
  /// and logging.
  const SkillPlanNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'skillPlanProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$skillPlanNotifierHash();

  @$internal
  @override
  SkillPlanNotifier create() => SkillPlanNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$skillPlanNotifierHash() => r'b6b63b2a1d67513b360d6861b4f147c83f5fbbbc';

/// Notifier for skill plan mutations (create, update, delete).
///
/// Handles all skill plan CRUD operations with proper error handling
/// and logging.

abstract class _$SkillPlanNotifier extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
        AsyncValue<void>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
