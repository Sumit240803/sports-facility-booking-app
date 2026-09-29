import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

final _when = DateFormat('d MMM, h:mm a');

/// Venue balances (money owed to venues) and payout history.
class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payouts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Balances'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(children: [_Balances(), _History()]),
      ),
    );
  }
}

class _Balances extends StatefulWidget {
  const _Balances();

  @override
  State<_Balances> createState() => _BalancesState();
}

class _BalancesState extends State<_Balances> with AutomaticKeepAliveClientMixin {
  late Future<List<VenueBalance>> _data;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _data = context.api.venueBalances();

  Future<void> _open(VenueBalance v) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VenuePayoutSheet(balance: v),
    );
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        setState(_load);
        await _data;
      },
      child: AsyncView<List<VenueBalance>>(
        future: _data,
        onRetry: () => setState(_load),
        isEmpty: (v) => v.isEmpty,
        empty: ListView(
          children: const [
            SizedBox(height: 60),
            MessageView(
              icon: Icons.check_circle_outline,
              title: 'All settled',
              message: 'No venue has a balance right now.',
            ),
          ],
        ),
        builder: (context, list) {
          final owed = list.where((v) => v.balancePaise > 0).fold<int>(0, (a, v) => a + v.balancePaise);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: scheme.primaryContainer,
                child: ListTile(
                  title: Text('Owed to venues', style: TextStyle(color: scheme.onPrimaryContainer)),
                  trailing: Text(
                    formatPaise(owed),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final v in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _open(v),
                  title: Text(v.venueName),
                  subtitle: Text('${v.city ?? ''} · ${v.payoutMode == 'route' ? 'automatic' : 'manual'} payouts'),
                  trailing: Text(
                    formatPaise(v.balancePaise),
                    style: TextStyle(fontWeight: FontWeight.w700, color: v.balancePaise < 0 ? scheme.error : null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VenuePayoutSheet extends StatefulWidget {
  const _VenuePayoutSheet({required this.balance});
  final VenueBalance balance;

  @override
  State<_VenuePayoutSheet> createState() => _VenuePayoutSheetState();
}

class _VenuePayoutSheetState extends State<_VenuePayoutSheet> {
  late Future<(PayoutSettings, int)> _data;

  String get _venueId => widget.balance.venueId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _data = context.api.adminPayoutSettings(_venueId);

  Future<void> _recordPayout(int balance) async {
    final amount = await promptText(
      context,
      'Amount sent (₹)',
      initial: balance > 0 ? paiseToRupeesText(balance) : null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      action: 'Next',
    );
    final paise = amount == null ? null : rupeesToPaise(amount);
    if (paise == null || paise <= 0 || !mounted) return;
    final reference = await promptText(context, 'Bank/UPI reference', label: 'UTR or transaction id', action: 'Next');
    if (reference == null || !mounted) return;
    final note = await promptText(context, 'Note (optional)', required: false, action: 'Record payout');
    if (note == null || !mounted) return;
    if (await runAction(
      context,
      () => context.api.recordPayout(_venueId, paise, reference, note),
      success: 'Payout of ${formatPaise(paise)} recorded',
    )) {
      setState(_load);
    }
  }

  Future<void> _adjust() async {
    final amount = await promptText(
      context,
      'Adjustment (₹)',
      label: 'Positive credits the venue, negative debits it',
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      action: 'Next',
    );
    final paise = amount == null ? null : rupeesToPaise(amount);
    if (paise == null || paise == 0 || !mounted) return;
    final note = await promptText(context, 'Reason', label: 'Shown in the venue\'s ledger', action: 'Apply');
    if (note == null || !mounted) return;
    if (await runAction(
      context,
      () => context.api.addAdjustment(_venueId, paise, note),
      success: 'Adjustment applied',
    )) {
      setState(_load);
    }
  }

  Future<void> _linkedAccount(PayoutSettings s) async {
    final id = await promptText(
      context,
      'Razorpay linked account',
      label: 'acc_… (leave empty to remove)',
      initial: s.linkedAccount,
      required: false,
    );
    if (id == null || !mounted) return;
    if (id.isNotEmpty && !RegExp(r'^acc_[A-Za-z0-9]{6,32}$').hasMatch(id)) {
      showMessage(context, 'Linked account ids look like acc_XXXXXXXX');
      return;
    }
    if (await runAction(
      context,
      () => context.api.setLinkedAccount(_venueId, id.isEmpty ? null : id),
      success: 'Saved',
    )) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: AsyncView<(PayoutSettings, int)>(
        future: _data,
        onRetry: () => setState(_load),
        builder: (context, d) {
          final (s, balance) = d;
          final dest = s.upi ?? [s.holder, s.accountNumber, s.ifsc].whereType<String>().join(' · ');
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(widget.balance.venueName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Balance ${formatPaise(balance)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s.upi != null ? Icons.qr_code : Icons.account_balance),
                title: Text(dest.isEmpty ? 'No payout details yet' : dest),
                subtitle: Text('${s.mode == 'route' ? 'Automatic (Route)' : 'Manual'} payouts'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(s.linkedAccount ?? 'No Razorpay linked account'),
                subtitle: const Text('Needed for automatic payouts'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _linkedAccount(s),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _recordPayout(balance),
                icon: const Icon(Icons.north_east),
                label: const Text('Record manual payout'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _adjust,
                icon: const Icon(Icons.tune),
                label: const Text('Ledger adjustment'),
              ),
              const SizedBox(height: 8),
              Text(
                'Record a payout only after you have sent the money by bank transfer or UPI.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _History extends StatefulWidget {
  const _History();

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> with AutomaticKeepAliveClientMixin {
  String? _status;
  late Future<(List<AdminPayout>, Map<String, String>)> _data;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final api = context.api;
    _data = Future.wait([api.adminPayouts(status: _status), api.venueBalances()])
        .then((r) => (r[0] as List<AdminPayout>, {for (final b in r[1] as List<VenueBalance>) b.venueId: b.venueName}));
  }

  Future<void> _resolve(AdminPayout p) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as paid'),
              onTap: () => Navigator.pop(context, 'paid'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Mark as failed (returns balance)'),
              onTap: () => Navigator.pop(context, 'failed'),
            ),
          ],
        ),
      ),
    );
    if (status == null || !mounted) return;
    final extra = await promptText(
      context,
      status == 'paid' ? 'Razorpay transfer id (optional)' : 'Failure reason',
      label: status == 'paid' ? 'trf_…' : null,
      required: status == 'failed',
      action: 'Resolve',
    );
    if (extra == null || !mounted) return;
    if (await runAction(
      context,
      () => context.api.resolvePayout(
        p.id,
        status,
        transferId: status == 'paid' ? extra : null,
        reason: status == 'failed' ? extra : null,
      ),
      success: 'Payout resolved',
    )) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              for (final s in [null, 'processing', 'paid', 'failed'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s == null ? 'All' : titleCase(s)),
                    selected: _status == s,
                    onSelected: (_) => setState(() {
                      _status = s;
                      _load();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<(List<AdminPayout>, Map<String, String>)>(
            future: _data,
            onRetry: () => setState(_load),
            isEmpty: (d) => d.$1.isEmpty,
            empty: const MessageView(icon: Icons.history, title: 'No payouts'),
            builder: (context, d) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: d.$1.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = d.$1[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: p.payout.status == 'processing' ? () => _resolve(p) : null,
                  title: Text('${formatPaise(p.payout.amountPaise)} · ${d.$2[p.venueId] ?? 'Venue'}'),
                  subtitle: Text(
                    [
                      _when.format(DateTime.parse(p.payout.createdAt).toLocal()),
                      titleCase(p.payout.mode),
                      if (p.payout.reference != null) 'Ref ${p.payout.reference}',
                      if (p.payout.failedReason != null) p.payout.failedReason!,
                    ].join(' · '),
                  ),
                  trailing: StatusPill(p.payout.status),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
