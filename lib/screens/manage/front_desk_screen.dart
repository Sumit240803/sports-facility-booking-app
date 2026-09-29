import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// A venue's bookings for one day, with walk-ins and check-in.
class FrontDeskScreen extends StatefulWidget {
  const FrontDeskScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<FrontDeskScreen> createState() => _FrontDeskScreenState();
}

class _FrontDeskScreenState extends State<FrontDeskScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  late Future<List<VenueBooking>> _bookings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _bookings = context.api.venueBookings(widget.venue.id, isoDate(_date));

  void _shift(int days) => setState(() {
        _date = _date.add(Duration(days: days));
        _load();
      });

  Future<void> _open(String bookingId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookingSheet(venue: widget.venue, bookingId: bookingId),
    );
    if (mounted) setState(_load);
  }

  Future<void> _lookup() async {
    final ref = await promptText(context, 'Find booking', label: 'Reference, e.g. EP-7K3M9Q', action: 'Find');
    if (ref == null || !mounted) return;
    try {
      final b = await context.api.venueBookingByReference(widget.venue.id, ref.toUpperCase());
      if (mounted) _open(b.booking.id);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _walkIn() async {
    final booked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WalkInScreen(venue: widget.venue, date: _date)),
    );
    if (booked == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Front desk'),
        actions: [IconButton(tooltip: 'Find by reference', onPressed: _lookup, icon: const Icon(Icons.qr_code_scanner))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _walkIn,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Walk-in'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now().subtract(const Duration(days: 60)),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (d != null) {
                        setState(() {
                          _date = d;
                          _load();
                        });
                      }
                    },
                    child: Text(
                      isToday ? 'Today, ${DateFormat('d MMM').format(_date)}' : DateFormat('EEE, d MMM yyyy').format(_date),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(_load);
                await _bookings;
              },
              child: AsyncView<List<VenueBooking>>(
                future: _bookings,
                onRetry: () => setState(_load),
                isEmpty: (b) => b.isEmpty,
                empty: ListView(children: const [
                  SizedBox(height: 60),
                  MessageView(icon: Icons.event_available, title: 'No bookings this day'),
                ]),
                builder: (context, list) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final vb = list[i];
                    final b = vb.booking;
                    return Card(
                      child: ListTile(
                        onTap: () => _open(b.id),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(formatTime(b.startsAt), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${b.durationMinutes}m', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        title: Text(vb.customerName ?? 'Player'),
                        subtitle: Text('${b.courtName ?? ''} · ${b.reference}\n'
                            '${formatPaise(b.totalPaise)} · ${titleCase(b.paymentMethod)} (${titleCase(b.paymentStatus)})'),
                        isThreeLine: true,
                        trailing: StatusPill(b.status),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.venue, required this.bookingId});
  final ManagedVenue venue;
  final String bookingId;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late Future<VenueBooking> _booking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _booking = context.api.venueBooking(widget.venue.id, widget.bookingId);

  Future<void> _do(Future<void> Function() action, String success) async {
    if (await runAction(context, action, success: success) && mounted) setState(_load);
  }

  Future<void> _checkIn(VenueBooking vb) async {
    final b = vb.booking;
    int? collected;
    if (b.paymentStatus == 'due') {
      final amount = await promptText(
        context,
        'Collected now (₹)',
        label: 'Leave empty if not collected yet',
        initial: paiseToRupeesText(b.totalPaise),
        required: false,
        action: 'Check in',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      );
      if (amount == null) return;
      collected = amount.isEmpty ? null : rupeesToPaise(amount);
    }
    if (!mounted) return;
    final api = context.api;
    await _do(() => api.checkIn(widget.venue.id, b.id, collectedPaise: collected), 'Checked in');
  }

  Future<void> _collect(VenueBooking vb) async {
    final amount = await promptText(
      context,
      'Amount collected (₹)',
      initial: paiseToRupeesText(vb.booking.totalPaise - (vb.collectedPaise ?? 0)),
      action: 'Record',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final paise = amount == null ? null : rupeesToPaise(amount);
    if (paise == null || !mounted) return;
    final api = context.api;
    await _do(() => api.collect(widget.venue.id, vb.booking.id, paise), 'Payment recorded');
  }

  Future<void> _cancel(VenueBooking vb) async {
    final reason = await promptText(context, 'Cancel booking', label: 'Reason (shown to the player)', action: 'Cancel booking');
    if (reason == null || !mounted) return;
    final api = context.api;
    await _do(() => api.venueCancelBooking(widget.venue.id, vb.booking.id, reason), 'Booking cancelled, player refunded');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: AsyncView<VenueBooking>(
        future: _booking,
        onRetry: () => setState(_load),
        builder: (context, vb) {
          final b = vb.booking;
          final api = context.api;
          final active = b.status == 'confirmed' || b.status == 'checked_in';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Row(children: [
                Expanded(
                  child: Text(b.reference,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
                StatusPill(b.status),
              ]),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(vb.customerName ?? 'Player'),
                subtitle: Text(vb.customerPhone ?? ''),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text('${b.courtName ?? ''} · ${formatDate(b.startsAt)}'),
                subtitle: Text('${formatTime(b.startsAt)} – ${formatTime(b.endsAt)} (${b.durationMinutes} min)'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: Text('${formatPaise(b.totalPaise)} · ${titleCase(b.paymentMethod)}'),
                subtitle: Text('${titleCase(b.paymentStatus)}'
                    '${vb.collectedPaise != null ? ' · collected ${formatPaise(vb.collectedPaise)}' : ''}'),
              ),
              if (vb.notes?.isNotEmpty ?? false)
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notes), title: Text(vb.notes!)),
              const SizedBox(height: 8),
              if (b.status == 'confirmed')
                FilledButton.icon(onPressed: () => _checkIn(vb), icon: const Icon(Icons.login), label: const Text('Check in')),
              if (active && b.paymentStatus == 'due') ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _collect(vb),
                  icon: const Icon(Icons.currency_rupee),
                  label: const Text('Record payment'),
                ),
              ],
              if (b.status == 'confirmed') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _do(() => api.markNoShow(widget.venue.id, b.id), 'Marked as no-show'),
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Mark no-show'),
                ),
              ],
              if (b.status == 'no_show') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _do(() => api.undoNoShow(widget.venue.id, b.id), 'No-show undone'),
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo no-show'),
                ),
              ],
              if (widget.venue.canEdit && (b.status == 'confirmed' || b.status == 'pending_payment')) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _cancel(vb),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel booking (full refund)'),
                ),
              ],
              if (vb.events.isNotEmpty) ...[
                const SectionTitle('History'),
                for (final e in vb.events)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, size: 10),
                    title: Text(titleCase('${e['to_status']}')),
                    subtitle: Text([
                      DateFormat('d MMM, h:mm a').format(DateTime.parse(e['created_at']).toLocal()),
                      if (e['note'] != null) e['note'],
                    ].join(' · ')),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Book a court for a walk-in / phone customer.
class WalkInScreen extends StatefulWidget {
  const WalkInScreen({super.key, required this.venue, required this.date});
  final ManagedVenue venue;
  final DateTime date;

  @override
  State<WalkInScreen> createState() => _WalkInScreenState();
}

class _WalkInScreenState extends State<WalkInScreen> {
  late DateTime _date = widget.date;
  late Future<Availability> _availability;
  String? _courtId;
  Slot? _slot;
  int? _minutes;
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+91');
  bool _saving = false;

  static const _bookable = {'available', 'closed', 'not_yet_open'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    _slot = null;
    _availability = context.api.manageAvailability(widget.venue.id, isoDate(_date));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(CourtAvailability court) async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final ok = await runAction(
      context,
      () => context.api.walkIn(
        widget.venue.id,
        courtId: court.id,
        date: isoDate(_date),
        start: _slot!.start,
        minutes: _minutes ?? court.minDurationMinutes,
        name: _name.text.trim(),
        phone: _phone.text.replaceAll(' ', ''),
      ),
      success: 'Walk-in booked',
    );
    if (ok) {
      nav.pop(true);
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walk-in booking')),
      body: AsyncView<Availability>(
        future: _availability,
        onRetry: () => setState(_load),
        builder: (context, a) {
          if (a.courts.isEmpty) {
            return const MessageView(icon: Icons.event_busy, title: 'No courts open on this day');
          }
          final court = a.courts.firstWhere((c) => c.id == _courtId, orElse: () => a.courts.first);
          final step = court.baseSlotMinutes;
          final durations = [for (var m = court.minDurationMinutes; m <= court.maxDurationMinutes; m += step) m];
          final minutes = durations.contains(_minutes) ? _minutes! : durations.first;
          final phoneOk = RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_phone.text.replaceAll(' ', ''));
          final valid = _slot != null && _name.text.trim().isNotEmpty && phoneOk;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('EEE, d MMM').format(_date)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateUtils.dateOnly(DateTime.now()),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (d != null) {
                    setState(() {
                      _date = d;
                      _load();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in a.courts)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: c.id == court.id,
                      onSelected: (_) => setState(() {
                        _courtId = c.id;
                        _slot = null;
                      }),
                    ),
                ],
              ),
              const SectionTitle('Start time'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in court.slots)
                    ChoiceChip(
                      label: Text(formatTime(s.start)),
                      selected: _slot?.start == s.start,
                      onSelected: _bookable.contains(s.status) ? (_) => setState(() => _slot = s) : null,
                    ),
                ],
              ),
              const SectionTitle('Duration'),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in durations)
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: m == minutes,
                      onSelected: (_) => setState(() => _minutes = m),
                    ),
                ],
              ),
              const SectionTitle('Customer'),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Phone', hintText: '+919876543210'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: valid && !_saving
                    ? () {
                        _minutes = minutes;
                        _save(court);
                      }
                    : null,
                child: const Text('Book (pay at venue)'),
              ),
            ],
          );
        },
      ),
    );
  }
}
