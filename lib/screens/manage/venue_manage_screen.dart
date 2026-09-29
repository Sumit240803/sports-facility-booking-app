import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'blocks_screen.dart';
import 'courts_screen.dart';
import 'dashboard_screen.dart';
import 'front_desk_screen.dart';
import 'hours_screen.dart';
import 'manage_reviews_screen.dart';
import 'photos_screen.dart';
import 'staff_screen.dart';
import 'venue_form_screen.dart';

typedef _Setup = ({ManagedVenue venue, int courts, int photos, int hours});

class VenueManageScreen extends StatefulWidget {
  const VenueManageScreen({super.key, required this.venueId});
  final String venueId;

  @override
  State<VenueManageScreen> createState() => _VenueManageScreenState();
}

class _VenueManageScreenState extends State<VenueManageScreen> {
  late Future<_Setup> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final api = context.api;
    _data = () async {
      final venue = await api.managedVenue(widget.venueId);
      final results = await Future.wait([
        api.courts(widget.venueId).then((c) => c.where((x) => x.isActive).length),
        api.photos(widget.venueId).then((p) => p.length).catchError((_) => 0),
        api.venueHours(widget.venueId).then((h) => h.length).catchError((_) => 0),
      ]);
      return (venue: venue, courts: results[0], photos: results[1], hours: results[2]);
    }();
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(_load);
  }

  Future<void> _submit(ManagedVenue v) async {
    if (!await confirm(context, 'Submit for review?',
        message: 'An admin will check the venue and make it live.', action: 'Submit')) {
      return;
    }
    if (!mounted) return;
    if (await runAction(context, () => context.api.submitVenue(v.id), success: 'Submitted for review')) {
      setState(_load);
    }
  }

  Future<void> _unpublish(ManagedVenue v) async {
    if (!await confirm(context, 'Take venue offline?',
        message: 'Players won\'t see it until you submit it again.', action: 'Unpublish')) {
      return;
    }
    if (!mounted) return;
    if (await runAction(context, () => context.api.unpublishVenue(v.id), success: 'Venue unpublished')) {
      setState(_load);
    }
  }

  Future<void> _delete(ManagedVenue v) async {
    final nav = Navigator.of(context);
    if (!await confirm(context, 'Delete ${v.name}?', message: 'This cannot be undone.', action: 'Delete')) return;
    if (!mounted) return;
    if (await runAction(context, () => context.api.deleteVenue(v.id), success: 'Venue deleted')) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage venue')),
      body: AsyncView<_Setup>(
        future: _data,
        onRetry: () => setState(_load),
        builder: (context, d) {
          final v = d.venue;
          final scheme = Theme.of(context).colorScheme;
          final checklist = [
            ('Address, city, location and phone', v.json['address_line'] != null && v.json['city'] != null && v.json['lat'] != null && v.json['phone'] != null),
            ('At least one active court with a price', d.courts > 0),
            ('Opening hours', d.hours > 0),
            ('At least one photo', d.photos > 0),
          ];
          final ready = checklist.every((c) => c.$2);

          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _data;
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(children: [
                        StatusPill(v.status),
                        const SizedBox(width: 8),
                        Text('You are ${v.access}', style: Theme.of(context).textTheme.labelMedium),
                      ]),
                      if (v.statusReason != null) ...[
                        const SizedBox(height: 8),
                        Text(v.statusReason!, style: TextStyle(color: scheme.error)),
                      ],
                    ],
                  ),
                ),

                if (v.status == 'draft' || v.status == 'rejected')
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Before you publish', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          for (final c in checklist)
                            Row(children: [
                              Icon(c.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 20, color: c.$2 ? scheme.primary : scheme.outline),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c.$1)),
                            ]),
                          if (v.isOwner) ...[
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: ready ? () => _submit(v) : null,
                              child: const Text('Submit for review'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SectionTitle('Daily operations'),
                _tile(Icons.point_of_sale, 'Front desk', 'Today\'s bookings, walk-ins, check-in',
                    () => _open(FrontDeskScreen(venue: v))),
                _tile(Icons.block, 'Blocks & closures', 'Maintenance, private events, holidays',
                    () => _open(BlocksScreen(venue: v))),
                if (v.isOwner)
                  _tile(Icons.insights, 'Dashboard', 'Bookings, earnings, occupancy',
                      () => _open(DashboardScreen(venue: v))),
                _tile(Icons.reviews_outlined, 'Reviews', 'Read and reply to player reviews',
                    () => _open(ManageReviewsScreen(venue: v))),

                const SectionTitle('Setup'),
                if (v.canEdit)
                  _tile(Icons.edit_outlined, 'Venue details', 'Name, address, booking rules',
                      () => _open(VenueFormScreen(venue: v))),
                _tile(Icons.sports_tennis, 'Courts & pricing', '${d.courts} active', () => _open(CourtsScreen(venue: v))),
                _tile(Icons.schedule, 'Opening hours', d.hours == 0 ? 'Not set' : '${d.hours} time ranges',
                    () => _open(HoursScreen(venue: v))),
                _tile(Icons.photo_library_outlined, 'Photos', '${d.photos} of 15', () => _open(PhotosScreen(venue: v))),
                if (v.isOwner || v.access == 'manager')
                  _tile(Icons.group_outlined, 'Staff', 'Managers and front-desk staff', () => _open(StaffScreen(venue: v))),

                if (v.isOwner) ...[
                  const SectionTitle('Danger zone'),
                  if (v.isListed)
                    _tile(Icons.visibility_off_outlined, 'Unpublish', 'Hide from players', () => _unpublish(v)),
                  _tile(Icons.delete_outline, 'Delete venue', 'Only when there are no upcoming bookings',
                      () => _delete(v), color: scheme.error),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
