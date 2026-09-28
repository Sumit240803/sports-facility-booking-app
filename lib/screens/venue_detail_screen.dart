import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/async_view.dart';
import 'booking_sheet.dart';
import 'explore_screen.dart';

class VenueDetailScreen extends StatefulWidget {
  const VenueDetailScreen({super.key, required this.idOrSlug, required this.title});
  final String idOrSlug;
  final String title;

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  late Future<PublicVenue> _venue;
  bool _favourite = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final api = context.api;
    _venue = api.venue(widget.idOrSlug);
    _venue.then((v) async {
      final favs = await api.favouriteIds();
      if (mounted) setState(() => _favourite = favs.contains(v.id));
    }).catchError((_) {});
  }

  Future<void> _toggleFavourite(PublicVenue v) async {
    final next = !_favourite;
    setState(() => _favourite = next);
    try {
      next ? await context.api.addFavourite(v.id) : await context.api.removeFavourite(v.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favourite = !next);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AsyncView<PublicVenue>(
        future: _venue,
        onRetry: () => setState(_load),
        builder: (context, v) => CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(v.name),
              expandedHeight: 240,
              actions: [
                IconButton(
                  tooltip: _favourite ? 'Remove from favourites' : 'Save',
                  onPressed: () => _toggleFavourite(v),
                  icon: Icon(_favourite ? Icons.favorite : Icons.favorite_border),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: VenueImage(url: v.photos.isEmpty ? null : v.photos.first.url),
              ),
            ),
            SliverToBoxAdapter(child: _Info(venue: v)),
            SliverToBoxAdapter(child: _SlotPicker(venue: v)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.venue});
  final PublicVenue venue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(venue.address, style: text.bodyMedium)),
              if (venue.ratingAvg != null) RatingPill(rating: venue.ratingAvg!, count: venue.ratingCount),
            ],
          ),
          if (venue.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(venue.description!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (venue.amenities.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Amenities', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in venue.amenities)
                  Chip(label: Text(titleCase(a)), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Date strip → court selector → slot grid.
class _SlotPicker extends StatefulWidget {
  const _SlotPicker({required this.venue});
  final PublicVenue venue;

  @override
  State<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<_SlotPicker> {
  late DateTime _date = DateUtils.dateOnly(DateTime.now());
  late Future<Availability> _availability;
  String? _courtId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    _availability = context.api.availability(widget.venue.id, isoDate(_date));
  }

  Future<void> _openBooking(Availability a, CourtAvailability court, Slot slot) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BookingSheet(venue: widget.venue, date: a.date, court: court, slot: slot),
    );
    if (booked == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = List.generate(14, (i) => DateUtils.dateOnly(DateTime.now()).add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text('Book a slot', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _DayTile(
              date: days[i],
              selected: DateUtils.isSameDay(days[i], _date),
              onTap: () => setState(() {
                _date = days[i];
                _load();
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<Availability>(
          future: _availability,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return MessageView(icon: Icons.event_busy, title: 'Couldn\'t load slots', message: '${snap.error}');
            }
            final a = snap.data!;
            if (a.courts.isEmpty) {
              return const MessageView(icon: Icons.event_busy, title: 'No courts open on this day');
            }
            final court = a.courts.firstWhere((c) => c.id == _courtId, orElse: () => a.courts.first);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final c in a.courts)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: const Icon(Icons.sports, size: 18),
                            label: Text('${c.name} · ${titleCase(c.sportId)}'),
                            selected: c.id == court.id,
                            onSelected: (_) => setState(() => _courtId = c.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const _Legend(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: court.slots.isEmpty
                      ? const MessageView(icon: Icons.event_busy, title: 'No slots on this day')
                      : GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.6,
                          children: [
                            for (final s in court.slots)
                              _SlotTile(slot: s, onTap: s.isAvailable ? () => _openBooking(a, court, s) : null),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.date, required this.selected, required this.onTap});
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(DateFormat.E().format(date), style: TextStyle(color: fg, fontSize: 12)),
              Text('${date.day}', style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, this.onTap});
  final Slot slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available = slot.isAvailable;
    return Material(
      color: available ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatTime(slot.start),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: available ? scheme.onPrimaryContainer : scheme.outline,
                decoration: available ? null : TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              available ? formatPaise(slot.pricePaise) : titleCase(slot.status),
              style: TextStyle(fontSize: 12, color: available ? scheme.onPrimaryContainer : scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 16, children: [
        dot(AppColors.available, 'Available'),
        dot(AppColors.unavailable, 'Booked / closed'),
      ]),
    );
  }
}
