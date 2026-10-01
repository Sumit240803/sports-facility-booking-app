import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/app_icons.dart';

/// Owner dashboard for the last 30 days.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Json> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  DateTimeRange? _range; // null = server default (last 30 days)

  void _load() => _data = context.api.venueDashboard(
    widget.venue.id,
    from: _range == null ? null : isoDate(_range!.start),
    to: _range == null ? null : isoDate(_range!.end),
  );

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 30)),
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now),
    );
    if (r == null) return;
    if (r.duration.inDays > 365) {
      if (mounted) showMessage(context, 'Pick at most 366 days');
      return;
    }
    setState(() {
      _range = r;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(tooltip: 'Date range', onPressed: _pickRange, icon: const AppIcon(AppIcons.calendarRange)),
          if (_range != null)
            IconButton(
              tooltip: 'Last 30 days',
              onPressed: () => setState(() {
                _range = null;
                _load();
              }),
              icon: const AppIcon(AppIcons.refresh),
            ),
        ],
      ),
      body: AsyncView<Json>(
        future: _data,
        onRetry: () => setState(_load),
        builder: (context, d) {
          final bookings = (d['bookings'] as Json?) ?? const {};
          final money = (d['money'] as Json?) ?? const {};
          final ratings = (d['ratings'] as Json?) ?? const {};
          final courts = ((d['courts'] as List?) ?? const []).cast<Json>();
          final todayCount = ((d['today'] as Json?)?['upcoming_bookings'] as num?)?.toInt() ?? 0;
          int n(Json m, String k) => (m[k] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _data;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${d['from']} → ${d['to']}', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.7,
                  children: [
                    _Stat('Bookings', '${n(bookings, 'total')}', AppIcons.calendarCheck),
                    _Stat('Booked value', formatPaise(n(money, 'booked_value_paise')), AppIcons.receipt),
                    _Stat('Your earnings', formatPaise(n(money, 'venue_earnings_paise')), AppIcons.wallet),
                    _Stat('Balance due', formatPaise(n(money, 'balance_paise')), AppIcons.savings),
                    _Stat('Collected at venue', formatPaise(n(money, 'collected_at_venue_paise')), AppIcons.counter),
                    _Stat(
                      'Rating',
                      ratings['average'] == null ? '—' : '${(ratings['average'] as num).toStringAsFixed(1)} ★',
                      AppIcons.star,
                    ),
                    _Stat('Cancellations', '${bookings['cancellation_rate_percent'] ?? 0}%', AppIcons.calendarOff),
                    _Stat('No-shows', '${bookings['no_show_rate_percent'] ?? 0}%', AppIcons.userBlock),
                  ],
                ),
                if (courts.isNotEmpty) ...[
                  const SectionTitle('Court occupancy'),
                  for (final c in courts)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${c['name']}')),
                              Text('${c['occupancy_percent'] ?? 0}%'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: ((c['occupancy_percent'] as num?) ?? 0) / 100,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const AppIcon(AppIcons.today),
                    title: const Text('Still to play today'),
                    trailing: Text('$todayCount', style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label, value;
  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppIcon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, style: Theme.of(context).textTheme.labelMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
