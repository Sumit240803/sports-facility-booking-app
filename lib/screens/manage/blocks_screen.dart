import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

final _fmt = DateFormat('EEE d MMM, h:mm a');

class BlocksScreen extends StatefulWidget {
  const BlocksScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends State<BlocksScreen> {
  late Future<(List<Block>, List<Court>)> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final api = context.api;
    _data = Future.wait([api.blocks(widget.venue.id), api.courts(widget.venue.id)])
        .then((r) => (r[0] as List<Block>, r[1] as List<Court>));
  }

  Future<void> _add(List<Court> courts) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BlockSheet(venue: widget.venue, courts: courts),
    );
    if (added == true && mounted) setState(_load);
  }

  Future<void> _delete(Block b) async {
    if (!await confirm(context, 'Remove this block?', action: 'Remove')) return;
    if (!mounted) return;
    if (await runAction(context, () => context.api.deleteBlock(widget.venue.id, b.id))) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Block>, List<Court>)>(
      future: _data,
      builder: (context, snap) => Scaffold(
        appBar: AppBar(title: const Text('Blocks & closures')),
        floatingActionButton: snap.hasData
            ? FloatingActionButton.extended(
                onPressed: () => _add(snap.data!.$2),
                icon: const Icon(Icons.add),
                label: const Text('Block time'),
              )
            : null,
        body: AsyncView<(List<Block>, List<Court>)>(
          future: _data,
          onRetry: () => setState(_load),
          isEmpty: (d) => d.$1.isEmpty,
          empty: const MessageView(
            icon: Icons.event_available,
            title: 'Nothing blocked',
            message: 'Block a court for maintenance or a private event, or close the whole venue for a holiday.',
          ),
          builder: (context, d) {
            final courtNames = {for (final c in d.$2) c.id: c.name};
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: d.$1.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = d.$1[i];
                return Card(
                  child: ListTile(
                    leading: Icon(b.courtId == null ? Icons.store : Icons.block),
                    title: Text(b.courtId == null ? 'Whole venue closed' : courtNames[b.courtId] ?? 'Court'),
                    subtitle: Text(
                      '${_fmt.format(DateTime.parse(b.startsAt).toLocal())}\n→ ${_fmt.format(DateTime.parse(b.endsAt).toLocal())}'
                      '${b.reason != null ? '\n${b.reason}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(b)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BlockSheet extends StatefulWidget {
  const _BlockSheet({required this.venue, required this.courts});
  final ManagedVenue venue;
  final List<Court> courts;

  @override
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
  String? _courtId; // null = whole venue
  late DateTime _start = _roundUp(DateTime.now());
  late DateTime _end = _start.add(const Duration(hours: 2));
  final _reason = TextEditingController();
  bool _saving = false;

  static DateTime _roundUp(DateTime t) {
    final base = DateTime(t.year, t.month, t.day, t.hour);
    return t.minute == 0 ? base : base.add(Duration(minutes: t.minute <= 30 ? 30 : 60));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final ok = await runAction(
      context,
      () => context.api.addBlock(widget.venue.id, courtId: _courtId, start: _start, end: _end, reason: _reason.text.trim()),
      success: 'Blocked',
    );
    if (ok) {
      nav.pop(true);
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Block time', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _courtId,
            decoration: const InputDecoration(labelText: 'What'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Whole venue (closed)')),
              for (final c in widget.courts) DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _courtId = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_arrow_outlined),
            title: const Text('From'),
            subtitle: Text(_fmt.format(_start)),
            onTap: () async {
              final v = await _pick(_start);
              if (v != null) {
                setState(() {
                  _start = v;
                  if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
                });
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_outlined),
            title: const Text('Until'),
            subtitle: Text(_fmt.format(_end)),
            onTap: () async {
              final v = await _pick(_end);
              if (v != null) setState(() => _end = v);
            },
          ),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || !_end.isAfter(_start) ? null : _save,
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}
