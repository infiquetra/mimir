import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/logging/logger.dart';
import '../../data/codex_auth_service.dart';

class DeviceAuthDialog extends ConsumerStatefulWidget {
  const DeviceAuthDialog({super.key});

  @override
  ConsumerState<DeviceAuthDialog> createState() => _DeviceAuthDialogState();
}

class _DeviceAuthDialogState extends ConsumerState<DeviceAuthDialog> {
  final _modelController = TextEditingController(text: codexDefaultModel);

  CodexAuthStatus? _status;
  CodexDeviceAuthSession? _session;
  bool _isLoading = true;
  bool _isSigningIn = false;
  bool _cancelled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Log.d('AUTH.CODEX.UI', 'DeviceAuthDialog.initState()');
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    Log.d('AUTH.CODEX.UI', '_loadStatus() - START');
    try {
      final db = ref.read(databaseProvider);
      final settings = await db.getAppSettings();
      final service = ref.read(codexAuthServiceProvider);
      final status = await service.getStatus();
      if (!mounted) return;
      _modelController.text = settings.llmModelName ?? codexDefaultModel;
      setState(() {
        _status = status;
        _isLoading = false;
        _error = null;
      });
      Log.d('AUTH.CODEX.UI', '_loadStatus() - SUCCESS');
    } catch (e, stack) {
      Log.e('AUTH.CODEX.UI', '_loadStatus() - FAILED', e, stack);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startFlow() async {
    Log.i('AUTH.CODEX.UI', 'User started AI sign-in');
    setState(() {
      _isSigningIn = true;
      _error = null;
      _session = null;
    });

    try {
      final db = ref.read(databaseProvider);
      await db.updateAppSettings(
        AppSettingsTableCompanion(
          llmModelName: drift.Value(_modelController.text.trim()),
          llmBaseUrl: const drift.Value(codexDefaultBaseUrl),
          llmApiKey: const drift.Value(null),
        ),
      );

      final service = ref.read(codexAuthServiceProvider);
      final session = await service.startDeviceFlow();
      if (!mounted) return;
      setState(() {
        _session = session;
      });

      await _openBrowser(session.verificationUri);

      await service.completeDeviceFlow(
        session,
        shouldCancel: () => _cancelled || !mounted,
      );

      final status = await service.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _isSigningIn = false;
        _session = null;
      });
      Log.i('AUTH.CODEX.UI', 'AI sign-in completed');
      Navigator.pop(context, true);
    } on CodexAuthCancelledException {
      Log.w('AUTH.CODEX.UI', 'AI sign-in cancelled');
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _session = null;
      });
    } catch (e, stack) {
      Log.e('AUTH.CODEX.UI', 'AI sign-in failed', e, stack);
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _importCodexCliTokens() async {
    Log.i('AUTH.CODEX.UI', 'User requested AI CLI credential import');
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final imported = await ref
          .read(codexAuthServiceProvider)
          .importCodexCliTokens();
      final status = await ref.read(codexAuthServiceProvider).getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _isLoading = false;
        _error = imported ? null : 'No valid AI CLI credentials found.';
      });
    } catch (e, stack) {
      Log.e('AUTH.CODEX.UI', 'AI CLI import failed', e, stack);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _clearAuth() async {
    Log.i('AUTH.CODEX.UI', 'User cleared AI auth');
    await ref.read(codexAuthServiceProvider).clear();
    await _loadStatus();
  }

  Future<void> _openBrowser(String url) async {
    Log.d('AUTH.CODEX.UI', '_openBrowser($url) - START');
    try {
      ProcessResult result;
      if (Platform.isMacOS) {
        result = await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        result = await Process.run('cmd', ['/c', 'start', '', url]);
      } else {
        result = await Process.run('xdg-open', [url]);
      }
      if (result.exitCode != 0) {
        Log.w('AUTH.CODEX.UI', 'Browser open command failed');
      }
    } catch (e, stack) {
      Log.e('AUTH.CODEX.UI', 'Failed to open browser', e, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('AI Authorization'),
      content: SizedBox(
        width: 520,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildStatus(theme),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _modelController,
                      enabled: !_isSigningIn,
                      decoration: const InputDecoration(
                        labelText: 'AI model',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_session != null) ...[
                      const SizedBox(height: 20),
                      _buildDeviceCode(theme, _session!),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        if (_status?.isAuthenticated ?? false)
          TextButton(
            onPressed: _isSigningIn ? null : _clearAuth,
            child: const Text('Sign Out'),
          ),
        TextButton(
          onPressed: _isSigningIn || _isLoading ? null : _importCodexCliTokens,
          child: const Text('Import CLI'),
        ),
        FilledButton(
          onPressed: _isSigningIn ? null : _startFlow,
          child: _isSigningIn
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign In'),
        ),
      ],
    );
  }

  Widget _buildStatus(ThemeData theme) {
    final status = _status;
    final authFilePath = status?.authFilePath;
    final isAuthenticated = status?.isAuthenticated ?? false;
    final color = isAuthenticated
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final label = switch (status?.kind) {
      CodexAuthStatusKind.authenticated => 'Signed in',
      CodexAuthStatusKind.expiring => 'Signed in; refresh needed soon',
      CodexAuthStatusKind.unauthenticated || null => 'Not signed in',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isAuthenticated ? Icons.check_circle : Icons.account_circle,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.titleMedium),
          ],
        ),
        if (authFilePath != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            authFilePath,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeviceCode(ThemeData theme, CodexDeviceAuthSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Open', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(
          session.verificationUri,
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text('Code', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            SelectableText(
              session.userCode,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              tooltip: 'Copy code',
              onPressed: () {
                Log.i('AUTH.CODEX.UI', 'User copied AI device code');
                Clipboard.setData(ClipboardData(text: session.userCode));
              },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Waiting for authorization...'),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    Log.d('AUTH.CODEX.UI', 'DeviceAuthDialog.dispose()');
    _cancelled = true;
    _modelController.dispose();
    super.dispose();
  }
}
