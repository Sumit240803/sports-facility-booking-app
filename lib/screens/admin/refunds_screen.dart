import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/app_icons.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key, this.initialStatus});
  final String? initialStatus;

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  late String? _status = widget.initialStatus;
  late Future<List<Refund>> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _data = context.api.refunds(status: _status);

  Future<void> _retry(Refund r) async {
    if (await runAction(context, () => context.api.retryRefund(r.id), success: 'Refund queued again')) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refunds')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in [null, 'pending', 'processing', 'processed', 'failed'])
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
            child: RefreshIndicator(
              onRefresh: () async {
                setState(_load);
                await _data;
              },
              child: AsyncView<List<Refund>>(
                future: _data,
                onRetry: () => setState(_load),
                isEmpty: (r) => r.isEmpty,
                empty: ListView(
                  children: const [
                    SizedBox(height: 60),
                    MessageView(icon: AppIcons.refund, title: 'No refunds'),
                  ],
                ),
                builder: (context, list) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${formatPaise(r.amountPaise)} · ${r.reference ?? 'Booking'}'),
                      subtitle: Text(
                        [
                          DateFormat('d MMM, h:mm a').format(DateTime.parse(r.createdAt).toLocal()),
                          if (r.reason != null) r.reason!,
                          if (r.attempts > 0) '${r.attempts} attempt${r.attempts == 1 ? '' : 's'}',
                          if (r.lastError != null) r.lastError!,
                        ].join(' · '),
                      ),
                      trailing: r.status == 'failed'
                          ? FilledButton.tonal(onPressed: () => _retry(r), child: const Text('Retry'))
                          : StatusPill(r.status),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
