import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../core/sport_icons.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import 'notifications_screen.dart';
import 'venue_detail_screen.dart';
import '../widgets/app_icons.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _pageSize = 20;

  List<CatalogItem> _sports = const [];
  List<String> _cities = const [];
  List<CatalogItem> _allAmenities = const [];
  String? _sport;
  String? _city;
  String _query = '';
  Set<String> _amenities = {};
  double? _minRating;
  String? _sort;
  Position? _here;
  bool _locating = false;
  Timer? _debounce;

  // Paged results
  final _scroll = ScrollController();
  List<VenueSearchResult> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0; // ignores responses from superseded searches
  bool _started = false;

  int get _activeFilters =>
      _amenities.length + (_minRating != null ? 1 : 0) + (_sort != null && _sort != 'distance' ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _city = context.profileStore.profile?.city;
      _loadFilters();
      _search();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final api = context.api;
      final results = await Future.wait([api.sports(), api.cities(), api.amenities()]);
      if (!mounted) return;
      final cities = results[1] as List<String>;
      final cityHasVenues = _city == null || cities.any((c) => c.toLowerCase() == _city!.toLowerCase());
      setState(() {
        _sports = results[0] as List<CatalogItem>;
        _cities = cities;
        _allAmenities = results[2] as List<CatalogItem>;
      });
      // The profile city may have no venues yet; show every city instead of an empty list.
      if (!cityHasVenues) {
        _city = null;
        _search();
      }
    } catch (_) {
      // Filters are optional; the list still works without them.
    }
  }

  /// Starts a new search from page 1.
  void _search() {
    _generation++;
    setState(() {
      _items = [];
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    final api = context.api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await api.searchVenues(
        city: _here == null ? _city : null,
        sport: _sport,
        q: _query.trim(),
        amenities: _amenities,
        minRating: _minRating,
        sort: _here != null ? (_sort ?? 'distance') : (_sort == 'distance' ? null : _sort),
        lat: _here?.latitude,
        lng: _here?.longitude,
        page: _page + 1,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = [..._items, ...page];
        _page++;
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _toggleNearMe() async {
    if (_here != null) {
      _here = null;
      if (_sort == 'distance') _sort = null;
      _search();
      return;
    }
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Turn on location services to find venues near you.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission is needed for "Near me".';
      }
      _here = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      _sort = 'distance';
      _search();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<(Set<String>, double?, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        amenities: _allAmenities,
        selected: _amenities,
        minRating: _minRating,
        sort: _sort,
        hasLocation: _here != null,
      ),
    );
    if (result == null) return;
    _amenities = result.$1;
    _minRating = result.$2;
    _sort = result.$3;
    _search();
  }

  Future<void> _pickCity() async {
    final city = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const AppIcon(AppIcons.globe),
              title: const Text('All cities'),
              selected: _city == null && _here == null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final c in _cities)
              ListTile(
                leading: const AppIcon(AppIcons.city),
                title: Text(c),
                selected: _here == null && _city?.toLowerCase() == c.toLowerCase(),
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (city == null) return;
    _city = city.isEmpty ? null : city;
    _here = null;
    if (_sort == 'distance') _sort = null;
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final firstName = (context.profileStore.profile?.fullName ?? '').trim().split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final where = _here != null ? 'Near you' : (_city ?? 'All cities');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _search(),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 72,
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName.isEmpty ? greeting : '$greeting, $firstName',
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  InkWell(
                    onTap: _cities.isEmpty ? null : _pickCity,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(_here != null ? AppIcons.nearMe : AppIcons.location, size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(where, style: text.labelLarge?.copyWith(color: scheme.primary)),
                        if (_cities.isNotEmpty) AppIcon(AppIcons.expand, size: 18, color: scheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Filters',
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: _activeFilters > 0,
                    label: Text('$_activeFilters'),
                    child: const AppIcon(AppIcons.filter),
                  ),
                ),
                const NotificationBell(),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(116),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SearchBar(
                        hintText: 'Search turfs, courts, areas…',
                        leading: const AppIcon(AppIcons.search),
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
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: _locating
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const AppIcon(AppIcons.nearMe, size: 18),
                              label: const Text('Near me'),
                              selected: _here != null,
                              onSelected: _locating ? null : (_) => _toggleNearMe(),
                            ),
                          ),
                          for (final s in [null, ..._sports])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: s == null ? null : AppIcon(sportIcon(s.id), size: 18),
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
            ..._results(),
          ],
        ),
      ),
    );
  }

  List<Widget> _results() {
    if (_items.isEmpty && _error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: AppIcons.offline,
            title: 'Couldn\'t load venues',
            message: '$_error',
            action: FilledButton.tonal(onPressed: _search, child: const Text('Retry')),
          ),
        ),
      ];
    }
    if (_items.isEmpty && (_loading || _hasMore)) {
      return const [SliverFillRemaining(hasScrollBody: false, child: SkeletonList(count: 3, image: true))];
    }
    if (_items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: AppIcons.searchOff,
            title: 'No venues found',
            message: _activeFilters > 0 || _sport != null || _query.isNotEmpty
                ? 'Try removing some filters.'
                : 'No venues are live here yet.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.separated(
          itemCount: _items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, i) => VenueCard(venue: _items[i]),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : _error != null
                ? TextButton(onPressed: _loadMore, child: const Text('Couldn\'t load more. Retry'))
                : !_hasMore
                ? Text(
                    '${_items.length} venue${_items.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ];
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
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.2),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VenueDetailScreen(idOrSlug: venue.slug, title: venue.name),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VenueImage(url: venue.coverUrl),
                  // Soft gradient so the badges stay readable on any photo
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, Colors.black45],
                      ),
                    ),
                  ),
                  if (venue.ratingAvg != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: RatingPill(rating: venue.ratingAvg!, count: venue.ratingCount),
                    ),
                  if (venue.distanceKm != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(AppIcons.nearMe, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${venue.distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      AppIcon(AppIcons.location, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  if (venue.sports.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final s in venue.sports) _Tag(label: titleCase(s), icon: sportIcon(s))],
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
  const _Tag({required this.label, this.icon});
  final String label;
  final AppIconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[AppIcon(icon!, size: 14, color: scheme.onSecondaryContainer), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer)),
        ],
      ),
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
          RatingStar(filled: true, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 2),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onTertiaryContainer),
          ),
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
      child: Center(child: AppIcon(AppIcons.venue, size: 48, color: scheme.onPrimaryContainer)),
    );
    if (url == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => ColoredBox(color: scheme.surfaceContainerHighest),
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.amenities,
    required this.selected,
    required this.minRating,
    required this.sort,
    required this.hasLocation,
  });
  final List<CatalogItem> amenities;
  final Set<String> selected;
  final double? minRating;
  final String? sort;
  final bool hasLocation;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _amenities = {...widget.selected};
  late double? _minRating = widget.minRating;
  late String? _sort = widget.sort;

  @override
  Widget build(BuildContext context) {
    final sorts = <(String?, String)>[
      if (widget.hasLocation) ('distance', 'Nearest') else (null, 'Name'),
      ('rating', 'Top rated'),
      ('newest', 'Newest'),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SectionTitle('Sort by'),
            Wrap(
              spacing: 8,
              children: [
                for (final s in sorts)
                  ChoiceChip(
                    label: Text(s.$2),
                    selected: _sort == s.$1,
                    onSelected: (_) => setState(() => _sort = s.$1),
                  ),
              ],
            ),
            const SectionTitle('Minimum rating'),
            Wrap(
              spacing: 8,
              children: [
                for (final r in <double?>[null, 3, 4, 4.5])
                  ChoiceChip(
                    label: Text(r == null ? 'Any' : '$r★ & up'),
                    selected: _minRating == r,
                    onSelected: (_) => setState(() => _minRating = r),
                  ),
              ],
            ),
            if (widget.amenities.isNotEmpty) ...[
              const SectionTitle('Amenities'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in widget.amenities)
                    FilterChip(
                      label: Text(a.name),
                      selected: _amenities.contains(a.id),
                      onSelected: (on) => setState(() => on ? _amenities.add(a.id) : _amenities.remove(a.id)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, (<String>{}, null, widget.hasLocation ? 'distance' : null)),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, (_amenities, _minRating, _sort)),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
