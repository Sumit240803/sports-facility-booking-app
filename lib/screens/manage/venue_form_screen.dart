import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/app_icons.dart';

/// Create a venue (pops its new id) or edit an existing one (pops true).
class VenueFormScreen extends StatefulWidget {
  const VenueFormScreen({super.key, this.venue});
  final ManagedVenue? venue;

  @override
  State<VenueFormScreen> createState() => _VenueFormScreenState();
}

class _VenueFormScreenState extends State<VenueFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Json _v = widget.venue?.json ?? const {};

  late final _name = TextEditingController(text: _v['name']);
  late final _description = TextEditingController(text: _v['description']);
  late final _phone = TextEditingController(text: _v['phone'] ?? context.profileStore.profile?.phone);
  late final _email = TextEditingController(text: _v['email']);
  late final _address = TextEditingController(text: _v['address_line']);
  late final _locality = TextEditingController(text: _v['locality']);
  late final _city = TextEditingController(text: _v['city'] ?? context.profileStore.profile?.city);
  late final _state = TextEditingController(text: _v['state']);
  late final _pincode = TextEditingController(text: _v['pincode']);
  late final _lat = TextEditingController(text: _v['lat']?.toString());
  late final _lng = TextEditingController(text: _v['lng']?.toString());
  late final _rules = TextEditingController(text: _v['rules']);

  late final Set<String> _amenities = {...((_v['amenities'] as List?) ?? const []).cast<String>()};
  late int _bookingWindow = _v['booking_window_days'] ?? 7;
  late int _listingWindow = _v['listing_window_days'] ?? 14;
  late int _minNotice = _v['min_notice_minutes'] ?? 60;
  late bool _payAtVenue = _v['pay_at_venue_enabled'] ?? true;
  late int _payAtVenueWindow = _v['pay_at_venue_window_minutes'] ?? 180;
  late List<({int hours, int percent})> _policy = [
    for (final p in ((_v['cancellation_policy'] as List?) ?? const []).cast<Json>())
      (hours: p['hours_before'] as int, percent: p['refund_percent'] as int),
  ];

  List<CatalogItem> _allAmenities = const [];
  bool _saving = false;

  bool get _isEdit => widget.venue != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allAmenities.isEmpty) {
      context.api
          .amenities()
          .then((a) {
            if (mounted) setState(() => _allAmenities = a);
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _phone,
      _email,
      _address,
      _locality,
      _city,
      _state,
      _pincode,
      _lat,
      _lng,
      _rules,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Json _body() => {
    'name': _name.text.trim(),
    'description': _description.text.trim(),
    'phone': _phone.text.replaceAll(' ', ''),
    'email': _email.text.trim(),
    'address_line': _address.text.trim(),
    'locality': _locality.text.trim(),
    'city': _city.text.trim(),
    'state': _state.text.trim(),
    'pincode': _pincode.text.trim(),
    'lat': double.tryParse(_lat.text.trim()),
    'lng': double.tryParse(_lng.text.trim()),
    'rules': _rules.text.trim(),
    'amenities': _amenities.toList(),
    'booking_window_days': _bookingWindow,
    'listing_window_days': _listingWindow,
    'min_notice_minutes': _minNotice,
    'pay_at_venue_enabled': _payAtVenue,
    'pay_at_venue_window_minutes': _payAtVenueWindow,
    'cancellation_policy': [
      for (final p in _policy) {'hours_before': p.hours, 'refund_percent': p.percent},
    ],
  };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final api = context.api;
    String? newId;
    final ok = await runAction(context, () async {
      if (_isEdit) {
        await api.updateVenue(widget.venue!.id, _body());
      } else {
        newId = await api.createVenue(_body());
      }
    }, success: _isEdit ? 'Venue updated' : 'Venue created');
    if (ok) {
      nav.pop(_isEdit ? true : newId);
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _addPolicyRow() async {
    final hours = await promptText(context, 'Hours before start', keyboardType: TextInputType.number, action: 'Next');
    if (hours == null || !mounted) return;
    final percent = await promptText(
      context,
      'Refund percent (0–100)',
      keyboardType: TextInputType.number,
      action: 'Add',
    );
    final h = int.tryParse(hours), p = int.tryParse(percent ?? '');
    if (h == null || p == null || h < 0 || h > 168 || p < 0 || p > 100) {
      if (mounted && percent != null) showMessage(context, 'Hours must be 0–168 and percent 0–100');
      return;
    }
    setState(() => _policy = [..._policy, (hours: h, percent: p)]..sort((a, b) => b.hours.compareTo(a.hours)));
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit venue' : 'New venue')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionTitle('Basics'),
            TextFormField(
              controller: _name,
              validator: required,
              decoration: const InputDecoration(labelText: 'Venue name *'),
            ),
            gap,
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v ?? '').trim().isEmpty || RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(v!.replaceAll(' ', ''))
                  ? null
                  : 'Use international format, e.g. +919876543210',
              decoration: const InputDecoration(labelText: 'Phone (required to publish)'),
            ),
            gap,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),

            const SectionTitle('Location'),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address (required to publish)'),
            ),
            gap,
            TextFormField(
              controller: _locality,
              decoration: const InputDecoration(labelText: 'Locality / area'),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _state,
                    decoration: const InputDecoration(labelText: 'State'),
                  ),
                ),
              ],
            ),
            gap,
            TextFormField(
              controller: _pincode,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v ?? '').isEmpty || RegExp(r'^[1-9][0-9]{5}$').hasMatch(v!) ? null : '6-digit PIN code',
              decoration: const InputDecoration(labelText: 'PIN code'),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => (v ?? '').isEmpty || double.tryParse(v!) != null ? null : 'Number',
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => (v ?? '').isEmpty || double.tryParse(v!) != null ? null : 'Number',
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tip: long-press the venue in Google Maps to copy its coordinates. Required to publish.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            if (_allAmenities.isNotEmpty) ...[
              const SectionTitle('Amenities'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _allAmenities)
                    FilterChip(
                      label: Text(a.name),
                      selected: _amenities.contains(a.id),
                      onSelected: (on) => setState(() => on ? _amenities.add(a.id) : _amenities.remove(a.id)),
                    ),
                ],
              ),
            ],

            const SectionTitle('Booking settings'),
            _NumberRow(
              label: 'Players can book up to',
              suffix: 'days ahead',
              value: _bookingWindow,
              min: 1,
              max: 7,
              onChanged: (v) => setState(() {
                _bookingWindow = v;
                if (_listingWindow < v) _listingWindow = v;
              }),
            ),
            _NumberRow(
              label: 'Show slots up to',
              suffix: 'days ahead',
              value: _listingWindow,
              min: _bookingWindow,
              max: 30,
              onChanged: (v) => setState(() => _listingWindow = v),
            ),
            _NumberRow(
              label: 'Minimum notice',
              suffix: 'minutes',
              value: _minNotice,
              min: 0,
              max: 1440,
              step: 15,
              onChanged: (v) => setState(() => _minNotice = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow pay at venue'),
              value: _payAtVenue,
              onChanged: (v) => setState(() => _payAtVenue = v),
            ),
            if (_payAtVenue)
              _NumberRow(
                label: 'Pay-at-venue only within',
                suffix: 'min of start',
                value: _payAtVenueWindow,
                min: 15,
                max: 720,
                step: 15,
                onChanged: (v) => setState(() => _payAtVenueWindow = v),
              ),

            SectionTitle(
              'Cancellation refunds',
              trailing: TextButton.icon(
                onPressed: _addPolicyRow,
                icon: const AppIcon(AppIcons.add),
                label: const Text('Add'),
              ),
            ),
            if (_policy.isEmpty)
              const Text('No rule added: the platform default policy applies.')
            else
              for (final p in _policy)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIcon(AppIcons.clock),
                  title: Text('${p.hours}h or more before start'),
                  subtitle: Text('${p.percent}% refund'),
                  trailing: IconButton(
                    icon: const AppIcon(AppIcons.delete),
                    onPressed: () => setState(() => _policy = [..._policy]..remove(p)),
                  ),
                ),

            const SectionTitle('House rules'),
            TextFormField(
              controller: _rules,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'e.g. Non-marking shoes only'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Save changes' : 'Create venue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label, suffix;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.filledTonal(
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const AppIcon(AppIcons.remove),
          ),
          SizedBox(
            width: 96,
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.filledTonal(
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
            icon: const AppIcon(AppIcons.add),
          ),
        ],
      ),
    );
  }
}
