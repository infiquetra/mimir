/// Onboarding wizard for first-time users.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/window/window_service.dart';
import '../../../core/window/window_types.dart';
import 'widgets/feature_tour_step.dart';
import 'widgets/tray_intro_step.dart';
import 'widgets/welcome_step.dart';

/// Onboarding wizard with 3 steps.
///
/// Step 1: Welcome + Add Character
/// Step 2: Feature Tour
/// Step 3: Tray Icon Guide + Startup Preference
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  StartupBehavior _selectedStartupBehavior = StartupBehavior.openDashboard;

  final int _totalSteps = 3;

  /// Moves to the next step.
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finishOnboarding();
    }
  }

  /// Moves to the previous step.
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  /// Skips onboarding entirely.
  void _skipOnboarding() {
    _finishOnboarding();
  }

  /// Called when startup behavior is selected in step 3.
  void _onStartupBehaviorChanged(StartupBehavior behavior) {
    setState(() {
      _selectedStartupBehavior = behavior;
    });
  }

  /// Completes onboarding and closes the window.
  Future<void> _finishOnboarding() async {
    final repository = ref.read(settingsRepositoryProvider);

    // Mark onboarding as complete
    await repository.completeOnboarding();

    // Save selected startup behavior
    await repository.setStartupBehavior(_selectedStartupBehavior);

    // Close onboarding window
    await WindowService.instance.closeWindow(WindowType.onboarding);

    // Open dashboard if user selected that preference
    if (_selectedStartupBehavior == StartupBehavior.openDashboard) {
      await WindowService.instance.openWindow(WindowType.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(theme),

          // Current step content
          Expanded(
            child: _buildCurrentStep(),
          ),

          // Navigation buttons
          _buildNavigationButtons(theme),
        ],
      ),
    );
  }

  /// Builds the step indicator at the top.
  Widget _buildStepIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalSteps, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Row(
            children: [
              if (index > 0)
                Container(
                  width: 40,
                  height: 2,
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? theme.colorScheme.primary
                      : isCompleted
                          ? theme.colorScheme.primary.withAlpha(128)
                          : theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: isActive || isCompleted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : Text(
                          '${index + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isActive
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Builds the current step widget.
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return const WelcomeStep();
      case 1:
        return const FeatureTourStep();
      case 2:
        return TrayIntroStep(
          selectedBehavior: _selectedStartupBehavior,
          onBehaviorChanged: _onStartupBehaviorChanged,
        );
      default:
        return const SizedBox();
    }
  }

  /// Builds the navigation buttons at the bottom.
  Widget _buildNavigationButtons(ThemeData theme) {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip button (only on first two steps)
          if (!isLastStep)
            TextButton(
              onPressed: _skipOnboarding,
              child: const Text('Skip'),
            )
          else
            const SizedBox(width: 80),

          // Back/Next buttons
          Row(
            children: [
              if (!isFirstStep)
                TextButton(
                  onPressed: _previousStep,
                  child: const Text('Back'),
                ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _nextStep,
                child: Text(isLastStep ? 'Get Started' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
