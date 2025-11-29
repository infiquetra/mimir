import 'package:flutter/material.dart';

/// A refresh button for the AppBar that shows loading state.
///
/// This widget provides a consistent refresh button across all screens.
/// It displays a spinning indicator while the refresh operation is in progress.
///
/// Example usage:
/// ```dart
/// AppBar(
///   title: Text('Screen Title'),
///   actions: [
///     RefreshAppBarAction(
///       onRefresh: () => _refreshData(ref, characterId),
///     ),
///   ],
/// )
/// ```
class RefreshAppBarAction extends StatefulWidget {
  const RefreshAppBarAction({
    required this.onRefresh,
    this.tooltip = 'Refresh',
    super.key,
  });

  /// The async callback to execute when the button is pressed.
  final Future<void> Function() onRefresh;

  /// The tooltip shown on hover (desktop) or long-press (mobile).
  final String tooltip;

  @override
  State<RefreshAppBarAction> createState() => _RefreshAppBarActionState();
}

class _RefreshAppBarActionState extends State<RefreshAppBarAction> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.refresh),
      tooltip: widget.tooltip,
      onPressed: _isRefreshing ? null : _handleRefresh,
    );
  }
}
