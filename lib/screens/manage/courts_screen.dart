import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'pricing_screen.dart';

class CourtsScreen extends StatefulWidget {
  const CourtsScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends State<CourtsScreen> {
  late Future<List<Court>> _courts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _courts = context.api.courts(widget.venue.id);

  Future<void> _edit([Court? court]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CourtFormScreen(venue: widget.venue, court: court)),
    );
    if (saved == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.venue.canEdit;
    return Scaffold(
      appBar: AppBar(title: const Text('Courts')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add), label: const Text('Add court'))
          : null,
      body: AsyncView<List<Court>>(
        future: _courts,
        onRetry: () => setState(_load),
        isEmpty: (c) => c.isEmpty,
        empty: const MessageView(
          icon: Icons.sports_tennis,
          title: 'No courts yet',
          message: 'A court is anything players book: a turf, a badminton court, a cricket net…',
        ),
        builder: (context, courts) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: courts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final c = courts[i];
            return Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${titleCase(c.sportId)} · ${c.isIndoor ? 'Indoor' : 'Outdoor'}'
                      '${c.surface != null ? ' · ${c.surface}' : ''}\n'
                      '${c.baseSlotMinutes}-min slots, book ${c.minDurationMinutes}–${c.maxDurationMinutes} min',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(c.pricePerHourPaise == null ? 'No price' : '${formatPaise(c.pricePerHourPaise)}/hr',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (!c.isActive) const StatusPill('inactive'),
                      ],
                    ),
                  ),
                  if (canEdit)
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PricingScreen(venue: widget.venue, court: c)),
                          ).then((_) => setState(_load)),
                          icon: const Icon(Icons.price_change_outlined),
                          label: const Text('Pricing'),
                        ),
                        TextButton.icon(
                          onPressed: () => _edit(c),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class CourtFormScreen extends StatefulWidget {
  const CourtFormScreen({super.key, required this.venue, this.court});
  final ManagedVenue venue;
  final Court? court;

  @override
  State<CourtFormScreen> createState() => _CourtFormScreenState();
}

class _CourtFormScreenState extends State<CourtFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Court? _c = widget.court;
  late final _name = TextEditingController(text: _c?.name);
  late final _surface = TextEditingController(text: _c?.surface);
  late final _capacity = TextEditingController(text: _c?.capacity?.toString());
  late final _price = TextEditingController(text: paiseToRupeesText(_c?.pricePerHourPaise));
  late String? _sport = _c?.sportId;
  late bool _indoor = _c?.isIndoor ?? false;
  late bool _active = _c?.isActive ?? true;
  late int _slot = _c?.baseSlotMinutes ?? 60;
  late int _min = _c?.minDurationMinutes ?? 60;
  late int _max = _c?.maxDurationMinutes ?? 120;
  List<CatalogItem> _sports = const [];
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sports.isEmpty) {
      context.api.sports().then((s) {
        if (mounted) setState(() => _sports = s);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _surface.dispose();
    _capacity.dispose();
    _price.dispose();
    super.dispose();
  }

  List<int> get _durationOptions => [for (var m = _slot; m <= 360; m += _slot) m];

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final api = context.api;
    final body = <String, Object?>{
      'name': _name.text.trim(),
      'sport_id': _sport,
      'is_indoor': _indoor,
      'surface': _surface.text.trim(),
      'capacity': int.tryParse(_capacity.text.trim()),
      'base_slot_minutes': _slot,
      'min_duration_minutes': _min,
      'max_duration_minutes': _max,
      'price_per_hour_paise': rupeesToPaise(_price.text),
      'is_active': _active,
    };
    final ok = await runAction(context, () async {
      if (_c == null) {
        await api.createCourt(widget.venue.id, body);
      } else {
        await api.updateCourt(widget.venue.id, _c.id, body);
      }
    }, success: 'Court saved');
    if (ok) {
      nav.pop(true);
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    if (!await confirm(context, 'Delete ${_c!.name}?', action: 'Delete')) return;
    if (!mounted) return;
    if (await runAction(context, () => context.api.deleteCourt(widget.venue.id, _c.id))) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(_c == null ? 'Add court' : 'Edit court'),
        actions: [
          if (_c != null) IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              decoration: const InputDecoration(labelText: 'Court name *', hintText: 'e.g. Court 1, Turf A'),
            ),
            gap,
            DropdownButtonFormField<String>(
              initialValue: _sport,
              validator: (v) => v == null ? 'Pick a sport' : null,
              decoration: const InputDecoration(labelText: 'Sport *'),
              items: [for (final s in _sports) DropdownMenuItem(value: s.id, child: Text(s.name))],
              onChanged: (v) => setState(() => _sport = v),
            ),
            gap,
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final p = rupeesToPaise(v!);
                return p == null || p < 100 ? 'Enter at least ₹1' : null;
              },
              decoration: const InputDecoration(
                labelText: 'Base price per hour (₹)',
                helperText: 'Required before the venue can go live. Add peak/off-peak rules under Pricing.',
              ),
            ),
            gap,
            Row(children: [
              Expanded(child: TextFormField(controller: _surface, decoration: const InputDecoration(labelText: 'Surface'))),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max players'),
                ),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Indoor'),
              value: _indoor,
              onChanged: (v) => setState(() => _indoor = v),
            ),
            const SectionTitle('Slots'),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30 min')),
                ButtonSegment(value: 60, label: Text('60 min')),
              ],
              selected: {_slot},
              onSelectionChanged: (s) => setState(() {
                _slot = s.first;
                _min = (_min / _slot).ceil() * _slot;
                _max = (_max / _slot).ceil() * _slot;
                if (_max < _min) _max = _min;
              }),
            ),
            gap,
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _min,
                  decoration: const InputDecoration(labelText: 'Min booking'),
                  items: [for (final m in _durationOptions) DropdownMenuItem(value: m, child: Text('$m min'))],
                  onChanged: (v) => setState(() {
                    _min = v!;
                    if (_max < _min) _max = _min;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('max-$_min-$_slot'),
                  initialValue: _max,
                  decoration: const InputDecoration(labelText: 'Max booking'),
                  items: [
                    for (final m in _durationOptions.where((m) => m >= _min))
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (v) => setState(() => _max = v!),
                ),
              ),
            ]),
            if (_c != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Inactive courts are hidden from players'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('Save court')),
          ],
        ),
      ),
    );
  }
}
