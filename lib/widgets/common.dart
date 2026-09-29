import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme/app_theme.dart';

void showMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$message')));
}

/// Runs [action], shows its error as a snackbar, and returns whether it succeeded.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }
}

Future<bool> confirm(BuildContext context, String title, {String? message, String action = 'Confirm'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

/// Asks for a line of text. Returns null when cancelled.
Future<String?> promptText(
  BuildContext context,
  String title, {
  String? label,
  String? initial,
  String action = 'Save',
  bool required = true,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (required && v.isEmpty) return;
            Navigator.pop(context, v);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Coloured pill for venue / application / booking statuses.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'live' || 'approved' || 'confirmed' || 'checked_in' || 'completed' => AppColors.available,
      'pending_review' || 'pending' || 'pending_payment' => AppColors.pending,
      'rejected' || 'suspended' || 'cancelled' || 'no_show' => AppColors.danger,
      _ => AppColors.unavailable,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        titleCase(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 16});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: color),
      ],
    );
  }
}

/// Parses rupees typed by a user into paise.
int? rupeesToPaise(String text) {
  final v = double.tryParse(text.trim());
  return v == null ? null : (v * 100).round();
}

String paiseToRupeesText(int? paise) => paise == null ? '' : (paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2);

/// Small labelled metric card used on dashboards.
class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, this.icon, {super.key, this.color, this.onTap});
  final String label, value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label, style: Theme.of(context).textTheme.labelMedium, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
