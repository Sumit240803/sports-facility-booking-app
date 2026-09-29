import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late Future<List<Reminder>> _reminders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _reminders = context.api.reminders();

  Future<void> _cancel(Reminder r) async {
    if (await runAction(context, () => context.api.cancelReminder(r.id))) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slot reminders')),
      body: AsyncView<List<Reminder>>(
        future: _reminders,
        loading: const SkeletonList(),
        onRetry: () => setState(_load),
        isEmpty: (r) => r.isEmpty,
        empty: const MessageView(
          icon: Icons.alarm_off,
          title: 'No reminders',
          message: 'Slots that aren\'t open for booking yet show a bell. Tap one to be reminded when booking opens.',
        ),
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = list[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: Text('${r.venueName ?? 'Venue'} · ${r.courtName ?? ''}'),
                subtitle: Text(
                  '${formatDate(r.slotStart)} at ${formatTime(r.slotStart)}\n'
                  'Opens ${DateFormat('d MMM, h:mm a').format(DateTime.parse(r.notifyAt).toLocal())}',
                ),
                isThreeLine: true,
                trailing: IconButton(tooltip: 'Cancel', icon: const Icon(Icons.close), onPressed: () => _cancel(r)),
              ),
            );
          },
        ),
      ),
    );
  }
}
