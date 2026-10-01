import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'hours_screen.dart';
import '../../widgets/app_icons.dart';

/// Base price + peak/off-peak rules for one court.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key, required this.venue, required this.court});
  final ManagedVenue venue;
  final Court court;

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late Future<List<PriceRule>> _loaded;
  List<PriceRule>? _rules;
  late int? _basePaise = widget.court.pricePerHourPaise;
  bool _dirty = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    _loaded = context.api.priceRules(widget.venue.id, widget.court.id).then((r) {
      _rules = [...r];
      _dirty = false;
      return r;
    });
  }

  Future<void> _editBase() async {
    final v = await promptText(
      context,
      'Base price per hour (₹)',
      initial: paiseToRupeesText(_basePaise),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final paise = v == null ? null : rupeesToPaise(v);
    if (paise == null || !mounted) return;
    if (await runAction(
      context,
      () => context.api.updateCourt(widget.venue.id, widget.court.id, {'price_per_hour_paise': paise}),
      success: 'Base price updated',
    )) {
      setState(() => _basePaise = paise);
    }
  }

  Future<void> _addRule() async {
    final rule = await showModalBottomSheet<PriceRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RuleSheet(),
    );
    if (rule == null) return;
    setState(() {
      _rules!.add(rule);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => context.api.savePriceRules(widget.venue.id, widget.court.id, _rules!),
      success: 'Price rules saved',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _load();
    });
  }

  String _describe(PriceRule r) {
    final when = r.date != null
        ? formatDate(r.date!)
        : (r.days!.length == 7 ? 'Every day' : r.days!.map((d) => dayShort[d]).join(', '));
    return '$when · ${prettyTime(r.start)} – ${prettyTime(r.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pricing · ${widget.court.name}'),
        actions: [if (_dirty) TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRule,
        icon: const AppIcon(AppIcons.add),
        label: const Text('Add rule'),
      ),
      body: AsyncView<List<PriceRule>>(
        future: _loaded,
        onRetry: () => setState(_load),
        builder: (context, _) {
          final rules = _rules!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                child: ListTile(
                  leading: const AppIcon(AppIcons.rupee),
                  title: const Text('Base price'),
                  subtitle: const Text('Used whenever no rule below matches'),
                  trailing: Text(
                    _basePaise == null ? 'Not set' : '${formatPaise(_basePaise)}/hr',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: _editBase,
                ),
              ),
              const SectionTitle('Rules'),
              const Text('Charge more at peak times or less off-peak. A rule for a specific date beats weekly rules.'),
              const SizedBox(height: 8),
              if (rules.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No rules — base price everywhere.')),
                ),
              for (final r in rules)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: AppIcon(r.date != null ? AppIcons.calendar : AppIcons.repeat),
                    title: Text('${formatPaise(r.pricePerHourPaise)}/hr'),
                    subtitle: Text(_describe(r)),
                    trailing: IconButton(
                      icon: const AppIcon(AppIcons.delete),
                      onPressed: () => setState(() {
                        rules.remove(r);
                        _dirty = true;
                      }),
                    ),
                  ),
                ),
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save rules')),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleSheet extends StatefulWidget {
  const _RuleSheet();

  @override
  State<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<_RuleSheet> {
  bool _weekly = true;
  final Set<int> _days = {1, 2, 3, 4, 5};
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String _start = '18:00';
  String _end = '22:00';
  final _price = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paise = rupeesToPaise(_price.text);
    final valid = paise != null && paise >= 100 && _end.compareTo(_start) > 0 && (!_weekly || _days.isNotEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add price rule', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Weekly'), icon: AppIcon(AppIcons.repeat)),
              ButtonSegment(value: false, label: Text('One date'), icon: AppIcon(AppIcons.calendar)),
            ],
            selected: {_weekly},
            onSelectionChanged: (s) => setState(() => _weekly = s.first),
          ),
          const SizedBox(height: 12),
          if (_weekly)
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
            )
          else
            OutlinedButton.icon(
              icon: const AppIcon(AppIcons.calendar),
              label: Text(formatDate(_date.toIso8601String())),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateUtils.dateOnly(DateTime.now()),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TimeDropdown(
                  label: 'From',
                  value: _start,
                  allowMidnightEnd: false,
                  onChanged: (v) => setState(() => _start = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TimeDropdown(label: 'To', value: _end, onChanged: (v) => setState(() => _end = v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Price per hour (₹)'),
          ),
          if (_end.compareTo(_start) <= 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Rules can\'t cross midnight — use 12:00 AM (midnight) as the end.'),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: valid
                ? () => Navigator.pop(
                    context,
                    PriceRule(
                      days: _weekly ? (_days.toList()..sort()) : null,
                      date: _weekly ? null : isoDate(_date),
                      start: _start,
                      end: _end,
                      pricePerHourPaise: paise,
                    ),
                  )
                : null,
            child: const Text('Add rule'),
          ),
        ],
      ),
    );
  }
}
