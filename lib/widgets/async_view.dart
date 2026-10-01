import './app_icons.dart';

import 'package:flutter/material.dart';

/// FutureBuilder with standard loading, error (with retry) and empty states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
  });

  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback onRetry;
  final bool Function(T)? isEmpty;
  final Widget? empty;

  /// Shown while loading (defaults to a spinner), e.g. a skeleton list.
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return MessageView(
            icon: AppIcons.offline,
            title: 'Something went wrong',
            message: '${snap.error}',
            action: FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          );
        }
        final data = snap.data as T;
        if (isEmpty?.call(data) ?? false) return empty ?? const SizedBox.shrink();
        return builder(context, data);
      },
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.message, this.action});

  final AppIconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon on a soft tinted disc reads as an illustration rather than a stray glyph.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.6), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), SizedBox(width: 180, child: action)],
          ],
        ),
      ),
    );
  }
}
