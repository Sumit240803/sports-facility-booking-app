import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/app_icons.dart';

const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const dayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// "00:00", "00:30" … "24:00".
final halfHours = [
  for (var m = 0; m <= 24 * 60; m += 30)
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
];

String prettyTime(String hhmm) {
  final h = int.parse(hhmm.substring(0, 2)), m = hhmm.substring(3);
  if (h == 24 || h == 0) return '12:$m AM${h == 24 ? ' (midnight)' : ''}';
  return '${h > 12 ? h - 12 : h}:$m ${h >= 12 ? 'PM' : 'AM'}';
}

/// Dropdown of half-hour times.
class TimeDropdown extends StatelessWidget {
  const TimeDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowMidnightEnd = true,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowMidnightEnd;

  @override
  Widget build(BuildContext context) {
    final options = allowMidnightEnd ? halfHours : halfHours.sublist(0, halfHours.length - 1);
    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : options.first,
      decoration: InputDecoration(labelText: label),
      menuMaxHeight: 320,
      items: [for (final t in options) DropdownMenuItem(value: t, child: Text(prettyTime(t)))],
      onChanged: (v) => onChanged(v!),
    );
  }
}

class HoursScreen extends StatefulWidget {
  const HoursScreen({super.key, required this.venue, this.court});
  final ManagedVenue venue;

  /// When set, edits this court's own hours instead of the venue's.
  final Court? court;

  @override
  State<HoursScreen> createState() => _HoursScreenState();
}

class _HoursScreenState extends State<HoursScreen> {
  late Future<List<HoursRange>> _loaded;
  List<HoursRange>? _hours;
  bool _dirty = false;
  bool _saving = false;

  /// Court mode: true while the court has its own hours (false = follows the venue).
  bool _customised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final api = context.api;
    final court = widget.court;
    _loaded =
        (court == null
                ? api.venueHours(widget.venue.id)
                : api.courtHours(widget.venue.id).then((m) {
                    _customised = m.containsKey(court.id);
                    // Start a customisation from the venue's hours.
                    return _customised ? Future.value(m[court.id]!) : api.venueHours(widget.venue.id);
                  }))
            .then((h) {
              _hours = [...h];
              _dirty = false;
              return h;
            });
  }

  Future<void> _followVenue() async {
    if (!await confirm(
      context,
      'Use venue hours?',
      message: '${widget.court!.name} will follow the venue\'s opening hours again.',
      action: 'Use venue hours',
    )) {
      return;
    }
    if (!mounted) return;
    if (await runAction(
      context,
      () => context.api.resetCourtHours(widget.venue.id, widget.court!.id),
      success: 'Court follows venue hours',
    )) {
      setState(_load);
    }
  }

  Future<void> _addRange({List<int>? days}) async {
    final result = await showModalBottomSheet<(Set<int>, String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RangeSheet(initialDays: days?.toSet()),
    );
    if (result == null) return;
    setState(() {
      for (final d in result.$1) {
        _hours!.add(HoursRange(d, result.$2, result.$3));
      }
      _hours!.sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.open.compareTo(b.open));
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => widget.court == null
          ? context.api.saveVenueHours(widget.venue.id, _hours!)
          : context.api.saveCourtHours(widget.venue.id, widget.court!.id, _hours!),
      success: 'Opening hours saved',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.venue.canEdit;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await confirm(context, 'Discard changes?', action: 'Discard')) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.court == null ? 'Opening hours' : 'Hours · ${widget.court!.name}'),
          actions: [
            if (canEdit && _dirty) TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
            if (canEdit && widget.court != null && _customised && !_dirty)
              TextButton(onPressed: _followVenue, child: const Text('Use venue hours')),
          ],
        ),
        floatingActionButton: canEdit
            ? FloatingActionButton.extended(
                onPressed: () => _addRange(),
                icon: const AppIcon(AppIcons.add),
                label: const Text('Add hours'),
              )
            : null,
        body: AsyncView<List<HoursRange>>(
          future: _loaded,
          onRetry: () => setState(_load),
          builder: (context, _) {
            final hours = _hours!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    widget.court == null
                        ? 'Hours apply to all courts unless a court has its own. Add several ranges per day for a break '
                              '(e.g. 6–11 AM and 4–11 PM). A range may end after midnight.'
                        : _customised
                        ? 'This court has its own hours.'
                        : 'This court follows the venue hours shown below. Change and save them to give it its own.',
                  ),
                ),
                for (var d = 0; d < 7; d++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(dayNames[d], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!hours.any((h) => h.day == d)) const Text('Closed'),
                          for (final h in hours.where((h) => h.day == d))
                            InputChip(
                              label: Text('${prettyTime(h.open)} – ${prettyTime(h.close)}'),
                              onDeleted: canEdit
                                  ? () => setState(() {
                                      hours.remove(h);
                                      _dirty = true;
                                    })
                                  : null,
                            ),
                        ],
                      ),
                      trailing: canEdit
                          ? IconButton(
                              icon: const AppIcon(AppIcons.add),
                              onPressed: () => _addRange(days: [d]),
                            )
                          : null,
                    ),
                  ),
                if (_dirty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save hours')),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({this.initialDays});
  final Set<int>? initialDays;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late final Set<int> _days = widget.initialDays ?? {0, 1, 2, 3, 4, 5, 6};
  String _open = '06:00';
  String _close = '23:00';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add opening hours', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(dayShort[d]),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TimeDropdown(
                  label: 'Opens',
                  value: _open,
                  allowMidnightEnd: false,
                  onChanged: (v) => setState(() => _open = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TimeDropdown(label: 'Closes', value: _close, onChanged: (v) => setState(() => _close = v)),
              ),
            ],
          ),
          if (_close.compareTo(_open) <= 0 && _close != '24:00')
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Closes the next day (after midnight).')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _days.isEmpty || _open == _close ? null : () => Navigator.pop(context, (_days, _open, _close)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
