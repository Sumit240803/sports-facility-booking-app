import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/app_icons.dart';

final _when = DateFormat('d MMM, h:mm a');

/// Balance, ledger and payouts for a venue (owner only).
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<Earnings> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _data = context.api.earnings(widget.venue.id);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => PayoutSettingsScreen(venue: widget.venue))),
            icon: const AppIcon(AppIcons.bank),
            label: const Text('Payout details'),
          ),
        ],
      ),
      body: AsyncView<Earnings>(
        future: _data,
        onRetry: () => setState(_load),
        builder: (context, e) => RefreshIndicator(
          onRefresh: () async {
            setState(_load);
            await _data;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balance', style: TextStyle(color: scheme.onPrimaryContainer)),
                      Text(
                        formatPaise(e.balancePaise),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.balancePaise >= 0
                            ? (e.payoutMode == 'route'
                                  ? 'Paid out automatically every day.'
                                  : 'ZocoPlay transfers this to your bank/UPI.')
                            : 'You owe this commission on pay-at-venue bookings; it\'s deducted from future online earnings.',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Online bookings credit the price minus ${e.commissionPercent}% commission once played. '
                'Completed pay-at-venue bookings debit the ${e.commissionPercent}% commission. Walk-ins are free.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (e.payouts.isNotEmpty) ...[
                const SectionTitle('Recent payouts'),
                for (final p in e.payouts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const AppIcon(AppIcons.payout),
                    title: Text(formatPaise(p.amountPaise)),
                    subtitle: Text(
                      [
                        _when.format(DateTime.parse(p.createdAt).toLocal()),
                        if (p.reference != null) 'Ref ${p.reference}',
                        if (p.failedReason != null) p.failedReason!,
                      ].join(' · '),
                    ),
                    trailing: StatusPill(p.status),
                  ),
              ],
              const SectionTitle('Ledger'),
              if (e.ledger.isEmpty)
                const Text('No entries yet. They appear once bookings are played.')
              else
                for (final l in e.ledger)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppIcon(
                      l.amountPaise >= 0 ? AppIcons.addCircle : AppIcons.removeCircle,
                      color: l.amountPaise >= 0 ? scheme.primary : scheme.error,
                    ),
                    title: Text(l.description.isEmpty ? titleCase(l.type) : l.description),
                    subtitle: Text(_when.format(DateTime.parse(l.createdAt).toLocal())),
                    trailing: Text(
                      '${l.amountPaise >= 0 ? '+' : '−'}${formatPaise(l.amountPaise.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: l.amountPaise >= 0 ? scheme.primary : scheme.error,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class PayoutSettingsScreen extends StatefulWidget {
  const PayoutSettingsScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<PayoutSettingsScreen> createState() => _PayoutSettingsScreenState();
}

class _PayoutSettingsScreenState extends State<PayoutSettingsScreen> {
  late Future<PayoutSettings> _data;
  final _form = GlobalKey<FormState>();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  bool _useUpi = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    _data = context.api.payoutSettings(widget.venue.id).then((s) {
      _holder.text = s.holder ?? '';
      _ifsc.text = s.ifsc ?? '';
      _upi.text = s.upi ?? '';
      _account.clear(); // masked by the server; re-enter to change
      _useUpi = s.upi != null && s.accountNumber == null;
      return s;
    });
  }

  @override
  void dispose() {
    for (final c in [_holder, _account, _ifsc, _upi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(PayoutSettings current) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = _useUpi
        ? {
            'mode': current.mode,
            'upi_id': _upi.text.trim(),
            'account_holder_name': null,
            'bank_account_number': null,
            'bank_ifsc': null,
          }
        : {
            'mode': current.mode,
            'account_holder_name': _holder.text.trim(),
            if (_account.text.trim().isNotEmpty) 'bank_account_number': _account.text.trim(),
            'bank_ifsc': _ifsc.text.trim().toUpperCase(),
            'upi_id': null,
          };
    final ok = await runAction(
      context,
      () => context.api.savePayoutSettings(widget.venue.id, body),
      success: 'Payout details saved',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout details')),
      body: AsyncView<PayoutSettings>(
        future: _data,
        onRetry: () => setState(_load),
        builder: (context, s) => Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: AppIcon(s.mode == 'route' ? AppIcons.refresh : AppIcons.handshake),
                  title: Text(s.mode == 'route' ? 'Automatic daily payouts' : 'Manual payouts'),
                  subtitle: Text(
                    s.mode == 'route'
                        ? 'Linked account ${s.linkedAccount ?? ''}'
                        : 'ZocoPlay sends your balance to the account below.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Bank account'), icon: AppIcon(AppIcons.bank)),
                  ButtonSegment(value: true, label: Text('UPI'), icon: AppIcon(AppIcons.qr)),
                ],
                selected: {_useUpi},
                onSelectionChanged: (v) => setState(() => _useUpi = v.first),
              ),
              const SizedBox(height: 16),
              if (_useUpi)
                TextFormField(
                  controller: _upi,
                  validator: (v) => RegExp(r'^[a-zA-Z0-9._-]{2,64}@[a-zA-Z]{2,64}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'e.g. name@okicici',
                  decoration: const InputDecoration(labelText: 'UPI ID'),
                )
              else ...[
                TextFormField(
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Account holder name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _account,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return s.accountNumber == null ? 'Required' : null;
                    return RegExp(r'^\d{9,18}$').hasMatch(t) ? null : '9–18 digits';
                  },
                  decoration: InputDecoration(
                    labelText: 'Account number',
                    helperText: s.accountNumber != null ? 'Saved: ${s.accountNumber}. Leave empty to keep it.' : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ifsc,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch((v ?? '').trim().toUpperCase())
                      ? null
                      : 'e.g. HDFC0001234',
                  decoration: const InputDecoration(labelText: 'IFSC'),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(onPressed: _saving ? null : () => _save(s), child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
