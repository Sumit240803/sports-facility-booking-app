import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import 'notifications_screen.dart';
import 'venue_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<CatalogItem> _sports = const [];
  List<String> _cities = const [];
  String? _sport;
  String? _city;
  String _query = '';
  Timer? _debounce;
  late Future<List<VenueSearchResult>> _venues;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sports.isEmpty) {
      _loadFilters();
      _search();
    }
  }

  Future<void> _loadFilters() async {
    try {
      final results = await Future.wait([context.api.sports(), context.api.cities()]);
      if (!mounted) return;
      setState(() {
        _sports = results[0] as List<CatalogItem>;
        _cities = results[1] as List<String>;
      });
    } catch (_) {
      // Filters are optional; the list still works without them.
    }
  }

  void _search() {
    setState(() {
      _venues = context.api.searchVenues(city: _city, sport: _sport, q: _query.trim());
    });
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a court'),
        actions: [
          const NotificationBell(),
          if (_cities.isNotEmpty)
            PopupMenuButton<String?>(
              tooltip: 'City',
              icon: const Icon(Icons.location_on_outlined),
              onSelected: (c) {
                _city = c;
                _search();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('All cities')),
                for (final c in _cities) PopupMenuItem(value: c, child: Text(c)),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  hintText: _city == null ? 'Search venues' : 'Search venues in $_city',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: _onQueryChanged,
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final s in [null, ..._sports])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s?.name ?? 'All sports'),
                          selected: _sport == s?.id,
                          onSelected: (_) {
                            _sport = s?.id;
                            _search();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _search();
          await _venues;
        },
        child: AsyncView<List<VenueSearchResult>>(
          future: _venues,
          onRetry: _search,
          isEmpty: (v) => v.isEmpty,
          empty: const MessageView(
            icon: Icons.search_off,
            title: 'No venues found',
            message: 'Try a different sport or city.',
          ),
          builder: (context, venues) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: venues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) => VenueCard(venue: venues[i]),
          ),
        ),
      ),
    );
  }
}

class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue});
  final VenueSearchResult venue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final place = [venue.locality, venue.city].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VenueDetailScreen(idOrSlug: venue.slug, title: venue.name)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: VenueImage(url: venue.coverUrl)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(venue.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                      if (venue.ratingAvg != null) RatingPill(rating: venue.ratingAvg!, count: venue.ratingCount),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(child: Text(place, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
                      if (venue.distanceKm != null)
                        Text('${venue.distanceKm!.toStringAsFixed(1)} km', style: text.labelMedium),
                    ],
                  ),
                  if (venue.sports.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final s in venue.sports) _Tag(label: titleCase(s))],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer)),
    );
  }
}

class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 2),
          Text('${rating.toStringAsFixed(1)} ($count)',
              style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onTertiaryContainer)),
        ],
      ),
    );
  }
}

class VenueImage extends StatelessWidget {
  const VenueImage({super.key, this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(child: Icon(Icons.stadium_outlined, size: 48, color: scheme.onPrimaryContainer)),
    );
    if (url == null) return placeholder;
    return Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
  }
}
