import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'explore_screen.dart';
import 'venue_detail_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  late Future<List<Favourite>> _favs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _favs = context.api.favourites();

  Future<void> _remove(Favourite f) async {
    if (await runAction(context, () => context.api.removeFavourite(f.id))) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: AsyncView<List<Favourite>>(
        future: _favs,
        onRetry: () => setState(_load),
        isEmpty: (f) => f.isEmpty,
        empty: const MessageView(
          icon: Icons.favorite_border,
          title: 'No favourites yet',
          message: 'Tap the heart on a venue to save it here.',
        ),
        builder: (context, favs) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: favs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final f = favs[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                enabled: f.available,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VenueDetailScreen(idOrSlug: f.slug, title: f.name)),
                ).then((_) => setState(_load)),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(dimension: 56, child: VenueImage(url: f.coverUrl)),
                ),
                title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(f.available ? f.place : 'Currently unavailable'),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: Icon(Icons.favorite, color: scheme.error),
                  onPressed: () => _remove(f),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
