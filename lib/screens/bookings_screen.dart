import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/async_view.dart';
import 'reviews.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _BookingsAppBar(),
        body: TabBarView(children: [_BookingList(scope: 'upcoming'), _BookingList(scope: 'past')]),
      ),
    );
  }
}

class _BookingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BookingsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('My bookings'),
        bottom: const TabBar(tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')]),
      );
}

class _BookingList extends StatefulWidget {
  const _BookingList({required this.scope});
  final String scope;

  @override
  State<_BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<_BookingList> with AutomaticKeepAliveClientMixin {
  late Future<List<Booking>> _bookings;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _bookings = context.api.myBookings(scope: widget.scope);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async {
        setState(_load);
        await _bookings;
      },
      child: AsyncView<List<Booking>>(
        future: _bookings,
        onRetry: () => setState(_load),
        isEmpty: (b) => b.isEmpty,
        empty: ListView(children: [
          const SizedBox(height: 80),
          MessageView(
            icon: Icons.event_available,
            title: widget.scope == 'upcoming' ? 'No upcoming bookings' : 'No past bookings',
            message: widget.scope == 'upcoming' ? 'Find a court on the Explore tab.' : null,
          ),
        ]),
        builder: (context, bookings) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _BookingCard(
            booking: bookings[i],
            onChanged: () => setState(_load),
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onChanged});
  final Booking booking;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: booking.id)),
          );
          if (changed == true) onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _DateBadge(iso: booking.startsAt),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.venueName ?? 'Venue', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      '${booking.courtName ?? ''} · ${formatTime(booking.startsAt)} – ${formatTime(booking.endsAt)}',
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    StatusChip(status: booking.status),
                  ],
                ),
              ),
              Text(formatPaise(booking.totalPaise), style: text.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.iso});
  final String iso;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = DateTime.parse(iso).toLocal();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(months[d.month - 1], style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer)),
        Text('${d.day}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' || 'checked_in' || 'completed' => AppColors.available,
      'pending_payment' => AppColors.pending,
      'cancelled' || 'no_show' => AppColors.danger,
      _ => AppColors.unavailable,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(titleCase(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Future<Booking> _booking;
  bool _changed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _booking = context.api.myBooking(widget.bookingId);

  Future<void> _cancel(Booking b) async {
    final refund = b.cancellation?['refund_paise'] as int?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_busy),
        title: const Text('Cancel booking?'),
        content: Text(refund != null && b.paymentStatus == 'paid'
            ? 'You will be refunded ${formatPaise(refund)}.'
            : 'This slot will be released for others.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.api.cancelBooking(b.id);
      _changed = true;
      setState(_load);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _review(Booking b) async {
    Review? existing;
    try {
      existing = await context.api.myReviewFor(b.venueId);
    } catch (_) {}
    if (!mounted) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WriteReviewSheet(venueId: b.venueId, venueName: b.venueName ?? 'this venue', existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: AsyncView<Booking>(
          future: _booking,
          onRetry: () => setState(_load),
          builder: (context, b) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Booking reference', style: text.labelLarge),
                      const SizedBox(height: 4),
                      if (b.status == 'confirmed' || b.status == 'pending_payment') ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: QrImageView(data: b.reference, size: 180, backgroundColor: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text('Show this at the front desk to check in', style: text.bodySmall),
                        const SizedBox(height: 12),
                      ],
                      SelectableText(b.reference,
                          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      StatusChip(status: b.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(children: [
                  ListTile(leading: const Icon(Icons.stadium_outlined), title: Text(b.venueName ?? ''), subtitle: Text(b.venueCity ?? '')),
                  ListTile(leading: const Icon(Icons.sports), title: Text(b.courtName ?? ''), subtitle: Text(titleCase(b.sportId ?? ''))),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(formatDate(b.startsAt)),
                    subtitle: Text('${formatTime(b.startsAt)} – ${formatTime(b.endsAt)} (${b.durationMinutes} min)'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(formatPaise(b.totalPaise)),
                    subtitle: Text('${titleCase(b.paymentMethod)} · ${titleCase(b.paymentStatus)}'),
                  ),
                  if (b.venuePhone != null)
                    ListTile(leading: const Icon(Icons.call_outlined), title: Text(b.venuePhone!)),
                ]),
              ),
              const SizedBox(height: 24),
              if (b.status == 'completed' && b.venueId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonalIcon(
                    onPressed: () => _review(b),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Rate this venue'),
                  ),
                ),
              if (b.isCancellable && (b.cancellation?['allowed'] ?? true) == true)
                OutlinedButton.icon(
                  onPressed: () => _cancel(b),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel booking'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
