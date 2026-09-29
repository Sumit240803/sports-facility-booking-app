import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../core/payment_flow.dart';
import '../data/models.dart';

/// Pick duration + payment method, show a live quote, then create the booking.
class BookingSheet extends StatefulWidget {
  const BookingSheet({super.key, required this.venue, required this.date, required this.court, required this.slot});

  final PublicVenue venue;
  final String date;
  final CourtAvailability court;
  final Slot slot;

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  late int _minutes = widget.court.minDurationMinutes;
  late String _method = widget.slot.payAtVenue ? 'pay_at_venue' : 'online';
  Future<Quote>? _quote;
  bool _booking = false;

  List<int> get _durations {
    final c = widget.court;
    final step = c.baseSlotMinutes <= 0 ? 30 : c.baseSlotMinutes;
    return [for (var m = c.minDurationMinutes; m <= c.maxDurationMinutes; m += step) m];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quote ??= _fetchQuote();
  }

  Future<Quote> _fetchQuote() => context.api.quote(widget.court.id, widget.date, widget.slot.start, _minutes, _method);

  void _refreshQuote() => setState(() => _quote = _fetchQuote());

  Future<void> _confirm() async {
    setState(() => _booking = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final b = await context.api.book(widget.court.id, widget.date, widget.slot.start, _minutes, _method);
      if (b.awaitingPayment && mounted) {
        // Slot is held for 10 minutes; pay now. If the user backs out, they can pay from My bookings.
        final paid = await payForBooking(context, b.id);
        navigator.pop(true);
        if (!paid) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Booking ${b.reference} is held for 10 minutes. Pay from My bookings to confirm it.'),
            ),
          );
        }
        return;
      }
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text('Booked! Reference ${b.reference}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.venue.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${widget.court.name} · ${formatDate(widget.slot.start)} · ${formatTime(widget.slot.start)}',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text('Duration', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in _durations)
                  ChoiceChip(
                    label: Text(m % 60 == 0 ? '${m ~/ 60} hr' : '${m / 60} hr'),
                    selected: m == _minutes,
                    onSelected: (_) {
                      _minutes = m;
                      _refreshQuote();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Payment', style: text.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  const ButtonSegment(value: 'online', label: Text('Pay online'), icon: Icon(Icons.credit_card)),
                  if (widget.slot.payAtVenue)
                    const ButtonSegment(value: 'pay_at_venue', label: Text('At venue'), icon: Icon(Icons.storefront)),
                ],
                selected: {_method},
                onSelectionChanged: (s) {
                  _method = s.first;
                  _refreshQuote();
                },
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Quote>(
              future: _quote,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text('${snap.error}', style: TextStyle(color: scheme.error));
                }
                final q = snap.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row('Subtotal', formatPaise(q.subtotalPaise)),
                        if (q.discountPaise > 0)
                          _row('Online discount (${q.discountPercent}%)', '− ${formatPaise(q.discountPaise)}'),
                        const Divider(height: 24),
                        _row('Total', formatPaise(q.totalPaise), bold: true),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _booking ? null : _confirm,
              child: _booking
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_method == 'online' ? 'Book & pay' : 'Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
