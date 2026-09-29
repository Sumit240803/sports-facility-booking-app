import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../core/push_service.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<(List<AppNotification>, int)> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _data = context.api.notifications();

  Future<void> _readAll() async {
    if (await runAction(context, context.api.markAllNotificationsRead)) setState(_load);
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      await runAction(context, () => context.api.markNotificationRead(n.id));
      if (mounted) setState(_load);
    }
    openNotificationTarget(n.data);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [TextButton(onPressed: _readAll, child: const Text('Mark all read'))],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _data;
        },
        child: AsyncView<(List<AppNotification>, int)>(
          future: _data,
          loading: const SkeletonList(),
          onRetry: () => setState(_load),
          isEmpty: (d) => d.$1.isEmpty,
          empty: ListView(
            children: const [
              SizedBox(height: 80),
              MessageView(icon: Icons.notifications_none, title: 'No notifications yet'),
            ],
          ),
          builder: (context, d) => ListView.separated(
            itemCount: d.$1.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = d.$1[i];
              return ListTile(
                onTap: () => _open(n),
                tileColor: n.isRead ? null : scheme.primaryContainer.withValues(alpha: 0.35),
                leading: CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(_icon(n.type), color: scheme.onSecondaryContainer),
                ),
                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700)),
                subtitle: Text(n.body),
                trailing: Text(
                  DateFormat('d MMM, h:mm a').format(DateTime.parse(n.createdAt).toLocal()),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                isThreeLine: n.body.length > 40,
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _icon(String type) {
    if (type.contains('booking')) return Icons.event_available;
    if (type.contains('reminder') || type.contains('slot')) return Icons.alarm;
    if (type.contains('review')) return Icons.rate_review_outlined;
    if (type.contains('refund') || type.contains('payment')) return Icons.payments_outlined;
    if (type.contains('venue') || type.contains('owner')) return Icons.store_outlined;
    return Icons.notifications_outlined;
  }
}

/// Bell icon with an unread badge; opens [NotificationsScreen].
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n = await context.api.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      // Badge is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _refresh();
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
