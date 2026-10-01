import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'admin_queues.dart';
import 'catalog_screen.dart';
import 'moderation_screen.dart';
import 'payouts_screen.dart';
import 'refunds_screen.dart';
import 'users_screen.dart';
import '../../widgets/app_icons.dart';

/// Admin home: platform numbers, things needing attention, and every admin tool.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<Json> _data;
  DateTimeRange? _range;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _data = context.api.adminDashboard(
    from: _range == null ? null : isoDate(_range!.start),
    to: _range == null ? null : isoDate(_range!.end),
  );

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(_load);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now),
    );
    if (r != null) {
      setState(() {
        _range = r;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(tooltip: 'Date range', onPressed: _pickRange, icon: const AppIcon(AppIcons.calendarRange)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _data;
        },
        child: AsyncView<Json>(
          future: _data,
          onRetry: () => setState(_load),
          builder: (context, d) {
            Json m(String k) => (d[k] as Json?) ?? const {};
            int n(Json j, String k) => (j[k] as num?)?.toInt() ?? 0;
            final money = m('money'), bookings = m('bookings'), venues = m('venues'), users = m('users');
            final attention = m('attention');
            final pendingOwners = n(d, 'pending_owner_applications');
            final pendingVenues = n(venues, 'pending_review');
            final failedRefunds = n(attention, 'failed_refunds');
            final stuckPayouts = n(attention, 'stuck_payouts');
            final failedNotifications = n(attention, 'failed_notifications');
            final topVenues = ((d['top_venues'] as List?) ?? const []).cast<Json>();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Text('${d['from']} → ${d['to']}', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),

                // Things that need an admin
                if (pendingOwners + pendingVenues + failedRefunds + stuckPayouts > 0)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Column(
                      children: [
                        if (pendingOwners > 0)
                          _AttentionTile(
                            '$pendingOwners owner application${pendingOwners == 1 ? '' : 's'} to review',
                            AppIcons.userAdd,
                            () => _open(const AdminQueuesScreen()),
                          ),
                        if (pendingVenues > 0)
                          _AttentionTile(
                            '$pendingVenues venue${pendingVenues == 1 ? '' : 's'} waiting for approval',
                            AppIcons.manage,
                            () => _open(const AdminQueuesScreen(initialIndex: 1)),
                          ),
                        if (failedRefunds > 0)
                          _AttentionTile(
                            '$failedRefunds failed refund${failedRefunds == 1 ? '' : 's'}',
                            AppIcons.refundOff,
                            () => _open(const RefundsScreen(initialStatus: 'failed')),
                          ),
                        if (stuckPayouts > 0)
                          _AttentionTile(
                            '$stuckPayouts payout${stuckPayouts == 1 ? '' : 's'} stuck in processing',
                            AppIcons.hourglass,
                            () => _open(const PayoutsScreen(initialTab: 1)),
                          ),
                      ],
                    ),
                  ),
                if (failedNotifications > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$failedNotifications notification deliveries failed (check email/push config).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                const SectionTitle('Platform'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.7,
                  children: [
                    StatTile('Bookings', '${n(bookings, 'total')}', AppIcons.calendarCheck),
                    StatTile('Gross value', formatPaise(n(money, 'gross_booking_value_paise')), AppIcons.receipt),
                    StatTile('Online captured', formatPaise(n(money, 'online_captured_paise')), AppIcons.card),
                    StatTile(
                      'Platform net',
                      formatPaise(n(money, 'platform_net_paise')),
                      AppIcons.savings,
                      color: n(money, 'platform_net_paise') < 0 ? AppColors.danger : null,
                    ),
                    StatTile(
                      'Owed to venues',
                      formatPaise(n(money, 'owed_to_venues_paise')),
                      AppIcons.bank,
                      onTap: () => _open(const PayoutsScreen()),
                    ),
                    StatTile(
                      'Refunds',
                      formatPaise(n(money, 'refunds_paise')),
                      AppIcons.refund,
                      onTap: () => _open(const RefundsScreen()),
                    ),
                    StatTile(
                      'Live venues',
                      '${n(venues, 'live')}',
                      AppIcons.storefront,
                      onTap: () => _open(const AdminQueuesScreen(initialIndex: 2)),
                    ),
                    StatTile(
                      'Users',
                      '${n(users, 'total')} (+${n(users, 'new_in_period')})',
                      AppIcons.users,
                      onTap: () => _open(const UsersScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Net = commission + online-discount cost + gateway fees '
                  '(${formatPaise(n(money, 'gateway_fees_paise'))} fees, '
                  '${formatPaise(n(money, 'discounts_given_paise'))} discounts).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SectionTitle('Tools'),
                Card(
                  child: Column(
                    children: [
                      _tool(
                        AppIcons.checklist,
                        'Approvals & venues',
                        'Owner applications, venue review, suspend',
                        () => _open(const AdminQueuesScreen()),
                      ),
                      _tool(AppIcons.users, 'Users', 'Search, change role, suspend', () => _open(const UsersScreen())),
                      _tool(
                        AppIcons.review,
                        'Review moderation',
                        'Hide abusive reviews',
                        () => _open(const ModerationScreen()),
                      ),
                      _tool(
                        AppIcons.wallet,
                        'Payouts',
                        'Venue balances, record payouts, adjustments',
                        () => _open(const PayoutsScreen()),
                      ),
                      _tool(AppIcons.refund, 'Refunds', 'Track and retry refunds', () => _open(const RefundsScreen())),
                      _tool(
                        AppIcons.category,
                        'Sports & amenities',
                        'Catalog shown to owners and players',
                        () => _open(const CatalogScreen()),
                      ),
                    ],
                  ),
                ),

                if (topVenues.isNotEmpty) ...[
                  const SectionTitle('Top venues'),
                  for (final (i, v) in topVenues.indexed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text('${v['name']}'),
                      subtitle: Text('${v['city'] ?? ''} · ${v['bookings'] ?? 0} bookings'),
                      trailing: Text(
                        formatPaise((v['booked_value_paise'] as num?)?.toInt()),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tool(AppIconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
    leading: IconBadge(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const AppIcon(AppIcons.chevronRight),
    onTap: onTap,
  );
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile(this.text, this.icon, this.onTap);
  final String text;
  final AppIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onErrorContainer;
    return ListTile(
      leading: AppIcon(icon, color: color),
      title: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: AppIcon(AppIcons.chevronRight, color: color),
      onTap: onTap,
    );
  }
}
