import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'booking_sheet.dart';
import 'explore_screen.dart';
import 'reviews.dart';
import '../widgets/app_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/sport_icons.dart';

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
    _venue
        .then((v) async {
          final favs = await api.favouriteIds();
          if (mounted) setState(() => _favourite = favs.contains(v.id));
        })
        .catchError((_) {});
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
                  icon: AppIcon(_favourite ? AppIcons.favourite : AppIcons.favourite),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(background: _PhotoCarousel(photos: v.photos)),
            ),
            SliverToBoxAdapter(child: _Info(venue: v)),
            SliverToBoxAdapter(child: _SlotPicker(venue: v)),
            SliverToBoxAdapter(
              child: VenueReviewsSection(venueId: v.id, venueName: v.name),
            ),
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

  static AppIconData _amenityIcon(String id) => switch (id) {
    'parking' => AppIcons.parking,
    'washroom' || 'shower' => AppIcons.shower,
    'changing-room' || 'locker' => AppIcons.locker,
    'drinking-water' => AppIcons.water,
    'floodlights' => AppIcons.floodlight,
    'equipment-rental' => AppIcons.racket,
    'first-aid' => AppIcons.firstAid,
    'seating' => AppIcons.seat,
    'cafeteria' => AppIcons.cafe,
    'wifi' => AppIcons.wifi,
    _ => AppIcons.check,
  };

  Future<void> _call(BuildContext context) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: venue.phone));
    if (!ok && context.mounted) showMessage(context, 'Couldn\'t open the dialer');
  }

  Future<void> _directions(BuildContext context) async {
    final q = venue.lat != null && venue.lng != null ? '${venue.lat},${venue.lng}' : '${venue.name}, ${venue.address}';
    final ok = await launchUrl(
      Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': q}),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) showMessage(context, 'Couldn\'t open maps');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(AppIcons.location, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(venue.address, style: text.bodyMedium)),
              if (venue.ratingAvg != null) ...[
                const SizedBox(width: 8),
                RatingPill(rating: venue.ratingAvg!, count: venue.ratingCount),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _directions(context),
                  icon: const AppIcon(AppIcons.nearMe, size: 18),
                  label: const Text('Directions'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
              ),
              if (venue.phone != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _call(context),
                    icon: const AppIcon(AppIcons.phone, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  ),
                ),
              ],
            ],
          ),
          if (venue.sports.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in venue.sports)
                  Chip(
                    avatar: AppIcon(sportIcon(s), size: 18, color: scheme.primary),
                    label: Text(titleCase(s)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (venue.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            Text(venue.description!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
          ],
          if (venue.amenities.isNotEmpty) ...[
            const SectionTitle('Amenities'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in venue.amenities)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(_amenityIcon(a), size: 18, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(titleCase(a), style: text.labelLarge),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (venue.rules?.isNotEmpty ?? false) ...[
            const SectionTitle('House rules'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(AppIcons.note, size: 20, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(venue.rules!, style: TextStyle(color: scheme.onTertiaryContainer)),
                  ),
                ],
              ),
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

  Future<void> _remind(Availability a, CourtAvailability court, Slot slot) async {
    final ok = await confirm(
      context,
      'Remind me?',
      message: 'Booking for this slot isn\x27t open yet. We\x27ll notify you when it opens.',
      action: 'Set reminder',
    );
    if (!ok || !mounted) return;
    await runAction(context, () => context.api.addReminder(court.id, a.date, slot.start), success: 'Reminder set');
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
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return MessageView(icon: AppIcons.calendarOff, title: 'Couldn\'t load slots', message: '${snap.error}');
            }
            final a = snap.data!;
            if (a.courts.isEmpty) {
              return const MessageView(icon: AppIcons.calendarOff, title: 'No courts open on this day');
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
                            avatar: const AppIcon(AppIcons.venue, size: 18),
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
                      ? const MessageView(icon: AppIcons.calendarOff, title: 'No slots on this day')
                      : GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.6,
                          children: [
                            for (final s in court.slots)
                              _SlotTile(
                                slot: s,
                                onTap: s.isAvailable
                                    ? () => _openBooking(a, court, s)
                                    : s.status == 'not_yet_open'
                                    ? () => _remind(a, court, s)
                                    : null,
                              ),
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
              Text(
                '${date.day}',
                style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700),
              ),
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
            if (slot.status == 'not_yet_open')
              AppIcon(AppIcons.alarm, size: 14, color: scheme.outline)
            else
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
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        children: [dot(AppColors.available, 'Available'), dot(AppColors.unavailable, 'Booked / closed')],
      ),
    );
  }
}

/// Swipeable header photos with a page indicator; tap opens a full-screen viewer.
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});
  final List<Photo> photos;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return const VenueImage();
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PhotoViewer(photos: photos, initial: i),
              ),
            ),
            child: VenueImage(url: photos[i].url),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('${_page + 1}/${photos.length}', style: const TextStyle(color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photos, required this.initial});
  final List<Photo> photos;
  final int initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
        controller: PageController(initialPage: initial),
        itemCount: photos.length,
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: CachedNetworkImage(imageUrl: photos[i].url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
