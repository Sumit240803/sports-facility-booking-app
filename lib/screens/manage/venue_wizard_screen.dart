import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_scope.dart';
import '../../core/sport_icons.dart';
import '../../data/models.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';

/// Guided, step-by-step venue creation. Pops the new venue id when created.
class VenueWizardScreen extends StatefulWidget {
  const VenueWizardScreen({super.key});

  @override
  State<VenueWizardScreen> createState() => _VenueWizardScreenState();
}

/// Cancellation refund presets owners pick from instead of building tiers by hand.
const _policies = <(String, String, String, List<(int, int)>)>[
  ('flexible', 'Flexible', 'Full refund up to 2 hours before', [(2, 100)]),
  ('standard', 'Standard', 'Full refund 24h before, 50% up to 6h before', [(24, 100), (6, 50)]),
  ('strict', 'Strict', 'Full refund only 48h or more before', [(48, 100)]),
];

class _VenueWizardScreenState extends State<VenueWizardScreen> {
  static const _steps = <(AppIconData, String, String)>[
    (AppIcons.venue, 'Basics', 'What should players call your venue?'),
    (AppIcons.location, 'Location', 'Help players find you'),
    (AppIcons.phone, 'Contact', 'How can players reach you?'),
    (AppIcons.checklist, 'Amenities', 'What does your venue offer?'),
    (AppIcons.calendar, 'Booking rules', 'Set how players can book'),
    (AppIcons.check, 'Review', 'Check everything before creating'),
  ];

  final _pages = PageController();
  int _step = 0;
  bool _saving = false;
  String? _error;

  // Basics
  final _name = TextEditingController();
  final _description = TextEditingController();
  // Location
  final _address = TextEditingController();
  final _locality = TextEditingController();
  late final _city = TextEditingController(text: context.profileStore.profile?.city);
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  double? _lat, _lng;
  bool _locating = false;
  // Contact
  late final _phone = TextEditingController(text: context.profileStore.profile?.phone ?? '+91');
  final _email = TextEditingController();
  // Amenities
  final Set<String> _amenities = {};
  List<CatalogItem> _allAmenities = const [];
  // Booking rules
  int _bookingWindow = 7;
  int _listingWindow = 14;
  int _minNotice = 60;
  bool _payAtVenue = true;
  int _payAtVenueWindow = 180;
  String _policy = 'standard';
  final _rules = TextEditingController();

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
    _pages.dispose();
    for (final c in [_name, _description, _address, _locality, _city, _state, _pincode, _phone, _email, _rules]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation per step: returns a message to show, or null when the step is complete.

  static final _phoneRe = RegExp(r'^\+[1-9]\d{7,14}$');
  static final _pinRe = RegExp(r'^[1-9][0-9]{5}$');
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _problem(int step) {
    switch (step) {
      case 0:
        if (_name.text.trim().length < 3) return 'Give your venue a name (at least 3 characters).';
      case 1:
        if (_address.text.trim().isEmpty) return 'Enter the street address.';
        if (_city.text.trim().isEmpty) return 'Enter the city.';
        if (_pincode.text.trim().isNotEmpty && !_pinRe.hasMatch(_pincode.text.trim())) {
          return 'PIN code should be 6 digits.';
        }
        if (_lat == null) return 'Pin the venue on the map so players get accurate directions.';
      case 2:
        if (!_phoneRe.hasMatch(_phone.text.replaceAll(' ', ''))) {
          return 'Enter a phone number in international format, e.g. +919876543210.';
        }
        if (_email.text.trim().isNotEmpty && !_emailRe.hasMatch(_email.text.trim())) return 'That email looks wrong.';
    }
    return null;
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    _pages.animateToPage(step, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _next() {
    final problem = _problem(_step);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_step < _steps.length - 1) {
      _go(_step + 1);
    } else {
      _create();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.maybePop(context);
    } else {
      _go(_step - 1);
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Turn on location services first.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission is needed to pin your venue.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      setState(() {
        _lat = double.parse(pos.latitude.toStringAsFixed(6));
        _lng = double.parse(pos.longitude.toStringAsFixed(6));
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _enterCoordinates() async {
    final value = await promptText(
      context,
      'Paste coordinates',
      label: 'e.g. 28.5245, 77.2066 (long-press the spot in Google Maps to copy)',
      initial: _lat == null ? null : '$_lat, $_lng',
      action: 'Use',
    );
    if (value == null) return;
    final parts = value.split(',').map((s) => double.tryParse(s.trim())).toList();
    if (parts.length != 2 || parts.contains(null) || parts[0]!.abs() > 90 || parts[1]!.abs() > 180) {
      if (mounted) showMessage(context, 'Use the format latitude, longitude');
      return;
    }
    setState(() {
      _lat = parts[0];
      _lng = parts[1];
      _error = null;
    });
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    final tiers = _policies.firstWhere((p) => p.$1 == _policy).$4;
    try {
      final id = await context.api.createVenue({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'phone': _phone.text.replaceAll(' ', ''),
        'email': _email.text.trim(),
        'address_line': _address.text.trim(),
        'locality': _locality.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pincode.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'amenities': _amenities.toList(),
        'rules': _rules.text.trim(),
        'booking_window_days': _bookingWindow,
        'listing_window_days': _listingWindow,
        'min_notice_minutes': _minNotice,
        'pay_at_venue_enabled': _payAtVenue,
        'pay_at_venue_window_minutes': _payAtVenueWindow,
        'cancellation_policy': [
          for (final t in tiers) {'hours_before': t.$1, 'refund_percent': t.$2},
        ],
      });
      nav.pop(id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (icon, title, subtitle) = _steps[_step];
    final last = _step == _steps.length - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _step == 0 ? 'Close' : 'Back',
            onPressed: _back,
            icon: AppIcon(_step == 0 ? AppIcons.close : AppIcons.chevronLeft),
          ),
          title: const Text('New venue'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_step + 1} of ${_steps.length}', style: text.labelLarge),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_step + 1) / _steps.length),
              duration: const Duration(milliseconds: 280),
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4),
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  IconBadge(icon, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleLarge),
                        Text(subtitle, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [_basics(), _location(), _contact(), _amenitiesStep(), _bookingRules(), _review()],
              ),
            ),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    AppIcon(AppIcons.error, size: 20, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(onPressed: _saving ? null : _back, child: const Text('Back')),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _next,
                        iconAlignment: IconAlignment.end,
                        icon: _saving
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : AppIcon(last ? AppIcons.check : AppIcons.chevronRight, size: 20),
                        label: Text(last ? 'Create venue' : 'Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Steps

  Widget _page(List<Widget> children) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: children);

  Widget _field(
    TextEditingController c,
    String label, {
    AppIconData? icon,
    String? hint,
    String? helper,
    TextInputType? keyboard,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization caps = TextCapitalization.sentences,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: caps,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: icon == null ? null : Padding(padding: const EdgeInsets.all(12), child: AppIcon(icon, size: 20)),
      ),
    ),
  );

  Widget _basics() => _page([
    _field(_name, 'Venue name', icon: AppIcons.venue, hint: 'e.g. Green Turf Arena', caps: TextCapitalization.words),
    _field(
      _description,
      'Short description (optional)',
      hint: 'Surface, size, what makes it great…',
      maxLines: 4,
      maxLength: 2000,
    ),
    const _Tip(
      icon: AppIcons.racket,
      text: 'You\'ll add courts, prices, opening hours and photos right after creating the venue.',
    ),
  ]);

  Widget _location() {
    final scheme = Theme.of(context).colorScheme;
    final pinned = _lat != null && _lng != null;
    return _page([
      _field(_address, 'Street address', icon: AppIcons.location, hint: 'Plot 12, Press Enclave Marg'),
      _field(_locality, 'Area / locality (optional)', hint: 'Saket', caps: TextCapitalization.words),
      Row(
        children: [
          Expanded(
            child: _field(_city, 'City', icon: AppIcons.city, caps: TextCapitalization.words),
          ),
          const SizedBox(width: 12),
          Expanded(child: _field(_state, 'State', caps: TextCapitalization.words)),
        ],
      ),
      _field(_pincode, 'PIN code (optional)', keyboard: TextInputType.number, maxLength: 6),
      Card(
        color: pinned ? scheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(
                    pinned ? AppIcons.check : AppIcons.nearMe,
                    color: pinned ? scheme.onPrimaryContainer : scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pinned ? 'Location pinned' : 'Pin your venue on the map',
                      style: TextStyle(fontWeight: FontWeight.w700, color: pinned ? scheme.onPrimaryContainer : null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pinned ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}' : 'Standing at the venue? Use your current location. Otherwise paste the coordinates from Google Maps.',
                style: TextStyle(color: pinned ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    icon: _locating
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const AppIcon(AppIcons.nearMe, size: 18),
                    label: Text(pinned ? 'Update' : 'Use current location'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _enterCoordinates,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    icon: const AppIcon(AppIcons.edit, size: 18),
                    label: const Text('Paste coordinates'),
                  ),
                  if (pinned)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$_lat,$_lng'}),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const AppIcon(AppIcons.outbound, size: 18),
                      label: const Text('Check on map'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _contact() => _page([
    _field(
      _phone,
      'Phone number',
      icon: AppIcons.phone,
      keyboard: TextInputType.phone,
      helper: 'Shown to players who book. Include the country code.',
    ),
    _field(_email, 'Email (optional)', icon: AppIcons.mail, keyboard: TextInputType.emailAddress),
  ]);

  Widget _amenitiesStep() {
    final scheme = Theme.of(context).colorScheme;
    if (_allAmenities.isEmpty) return const Center(child: CircularProgressIndicator());
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1,
      children: [
        for (final a in _allAmenities)
          _SelectTile(
            icon: amenityIcon(a.id),
            label: a.name,
            selected: _amenities.contains(a.id),
            onTap: () => setState(() => _amenities.contains(a.id) ? _amenities.remove(a.id) : _amenities.add(a.id)),
            scheme: scheme,
          ),
      ],
    );
  }

  Widget _bookingRules() {
    Widget choices<T>(String label, String help, List<(T, String)> options, T value, ValueChanged<T> onChanged) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              Text(help, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in options)
                    ChoiceChip(label: Text(o.$2), selected: value == o.$1, onSelected: (_) => onChanged(o.$1)),
                ],
              ),
            ],
          ),
        );

    return _page([
      choices<int>(
        'Players can book up to',
        'How far ahead bookings open.',
        const [(1, '1 day'), (3, '3 days'), (7, '7 days')],
        _bookingWindow,
        (v) => setState(() {
          _bookingWindow = v;
          if (_listingWindow < v) _listingWindow = v;
        }),
      ),
      choices<int>(
        'Show slots up to',
        'Players can see (and set reminders for) slots this far ahead.',
        [
          for (final d in const [7, 14, 30]) (d, '$d days'),
        ].where((o) => o.$1 >= _bookingWindow).toList(),
        _listingWindow,
        (v) => setState(() => _listingWindow = v),
      ),
      choices<int>(
        'Minimum notice',
        'Stop online bookings this close to the start time.',
        const [(0, 'None'), (30, '30 min'), (60, '1 hour'), (120, '2 hours')],
        _minNotice,
        (v) => setState(() => _minNotice = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Allow pay at venue'),
        subtitle: const Text('Players can book now and pay in cash or UPI when they arrive.'),
        value: _payAtVenue,
        onChanged: (v) => setState(() => _payAtVenue = v),
      ),
      if (_payAtVenue)
        choices<int>(
          'Pay-at-venue only for games starting within',
          'Further-out bookings must be paid online.',
          const [(60, '1 hour'), (180, '3 hours'), (720, '12 hours')],
          _payAtVenueWindow,
          (v) => setState(() => _payAtVenueWindow = v),
        ),
      Text('Cancellation policy', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      for (final p in _policies)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PolicyCard(
            title: p.$2,
            subtitle: p.$3,
            selected: _policy == p.$1,
            onTap: () => setState(() => _policy = p.$1),
          ),
        ),
      const SizedBox(height: 8),
      _field(_rules, 'House rules (optional)', icon: AppIcons.note, hint: 'e.g. Non-marking shoes only', maxLines: 3),
    ]);
  }

  Widget _review() {
    final amenityNames = _allAmenities.where((a) => _amenities.contains(a.id)).map((a) => a.name).join(', ');
    final policy = _policies.firstWhere((p) => p.$1 == _policy);
    String minutes(int m) => m == 0 ? 'none' : (m % 60 == 0 ? '${m ~/ 60}h' : '${m}m');
    return _page([
      _ReviewSection(
        icon: AppIcons.venue,
        title: _name.text.trim(),
        lines: [if (_description.text.trim().isNotEmpty) _description.text.trim()],
        onEdit: () => _go(0),
      ),
      _ReviewSection(
        icon: AppIcons.location,
        title: 'Location',
        lines: [
          [
            _address.text.trim(),
            _locality.text.trim(),
            _city.text.trim(),
            _state.text.trim(),
            _pincode.text.trim(),
          ].where((s) => s.isNotEmpty).join(', '),
          if (_lat != null) 'Pinned at ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
        ],
        onEdit: () => _go(1),
      ),
      _ReviewSection(
        icon: AppIcons.phone,
        title: 'Contact',
        lines: [_phone.text.trim(), if (_email.text.trim().isNotEmpty) _email.text.trim()],
        onEdit: () => _go(2),
      ),
      _ReviewSection(
        icon: AppIcons.checklist,
        title: 'Amenities',
        lines: [amenityNames.isEmpty ? 'None selected' : amenityNames],
        onEdit: () => _go(3),
      ),
      _ReviewSection(
        icon: AppIcons.calendar,
        title: 'Booking rules',
        lines: [
          'Book up to $_bookingWindow day${_bookingWindow == 1 ? '' : 's'} ahead · show $_listingWindow days',
          'Minimum notice: ${minutes(_minNotice)}',
          _payAtVenue ? 'Pay at venue within ${minutes(_payAtVenueWindow)} of start' : 'Online payment only',
          '${policy.$2} cancellation: ${policy.$3.toLowerCase()}',
        ],
        onEdit: () => _go(4),
      ),
      const SizedBox(height: 4),
      const _Tip(
        icon: AppIcons.checklist,
        text: 'Next: add at least one court with a price, opening hours and a photo, then submit for review.',
      ),
    ]);
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });
  final AppIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(icon, size: 28, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(top: 6, right: 6, child: AppIcon(AppIcons.check, size: 16, color: scheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 1.5 : 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AppIcon(selected ? AppIcons.check : AppIcons.dot, color: selected ? scheme.primary : scheme.outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.icon, required this.title, required this.lines, required this.onEdit});
  final AppIconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(l, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            IconButton(tooltip: 'Edit', onPressed: onEdit, icon: const AppIcon(AppIcons.edit, size: 20)),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final AppIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}
