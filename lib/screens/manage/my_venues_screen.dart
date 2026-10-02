import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../explore_screen.dart';
import 'venue_wizard_screen.dart';
import 'venue_manage_screen.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/app_icons.dart';

/// Venues the user owns or works at. Owners can create new ones.
class MyVenuesScreen extends StatefulWidget {
  const MyVenuesScreen({super.key, this.standalone = false});

  /// True when pushed from the profile (staff) rather than shown as a tab.
  final bool standalone;

  @override
  State<MyVenuesScreen> createState() => _MyVenuesScreenState();
}

class _MyVenuesScreenState extends State<MyVenuesScreen> {
  late Future<List<VenueSummary>> _venues;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _venues = context.api.myVenues();

  Future<void> _create() async {
    final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const VenueWizardScreen()));
    if (!mounted) return;
    setState(_load);
    if (id != null) _open(id);
  }

  Future<void> _open(String venueId) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VenueManageScreen(venueId: venueId)));
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.profileStore.profile?.canOwnVenues ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.standalone ? 'Venues I work at' : 'My venues')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const AppIcon(AppIcons.add),
              label: const Text('New venue'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _venues;
        },
        child: AsyncView<List<VenueSummary>>(
          future: _venues,
          loading: const SkeletonList(),
          onRetry: () => setState(_load),
          isEmpty: (v) => v.isEmpty,
          empty: ListView(
            children: [
              const SizedBox(height: 80),
              MessageView(
                icon: AppIcons.manage,
                title: canCreate ? 'No venues yet' : 'You aren\'t staff at any venue',
                message: canCreate
                    ? 'Create your first venue, add courts, hours and prices, then submit it for review.'
                    : 'Venue owners can invite you by your email address.',
              ),
            ],
          ),
          builder: (context, venues) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: venues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final v = venues[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  onTap: () => _open(v.id),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox.square(dimension: 56, child: VenueImage(url: v.coverUrl)),
                  ),
                  title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (v.place.isNotEmpty) Text(v.place),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          StatusPill(v.status),
                          if (v.role != null) Chip(label: Text(v.role!), visualDensity: VisualDensity.compact),
                        ],
                      ),
                    ],
                  ),
                  trailing: const AppIcon(AppIcons.chevronRight),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
