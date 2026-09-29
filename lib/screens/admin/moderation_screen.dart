import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../reviews.dart';

/// Hide or restore player reviews. Hidden reviews don't count toward ratings.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  String _status = 'visible';
  late Future<List<AdminReview>> _reviews;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _reviews = context.api.adminReviews(_status);

  Future<void> _hide(AdminReview r) async {
    final reason = await promptText(context, 'Hide review', label: 'Reason (kept for the record)', action: 'Hide');
    if (reason == null || !mounted) return;
    if (await runAction(context, () => context.api.hideReview(r.review.id, reason), success: 'Review hidden')) {
      setState(_load);
    }
  }

  Future<void> _unhide(AdminReview r) async {
    if (await runAction(context, () => context.api.unhideReview(r.review.id), success: 'Review visible again')) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review moderation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'visible', label: Text('Visible')),
                ButtonSegment(value: 'hidden', label: Text('Hidden')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() {
                _status = s.first;
                _load();
              }),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(_load);
                await _reviews;
              },
              child: AsyncView<List<AdminReview>>(
                future: _reviews,
                onRetry: () => setState(_load),
                isEmpty: (r) => r.isEmpty,
                empty: ListView(
                  children: const [
                    SizedBox(height: 60),
                    MessageView(icon: Icons.reviews_outlined, title: 'No reviews here'),
                  ],
                ),
                builder: (context, list) => ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(r.venueName, style: Theme.of(context).textTheme.labelLarge),
                        ),
                        ReviewTile(
                          review: r.review,
                          trailing: _status == 'visible'
                              ? TextButton(onPressed: () => _hide(r), child: const Text('Hide'))
                              : TextButton(onPressed: () => _unhide(r), child: const Text('Unhide')),
                        ),
                        if (r.hiddenReason != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: Text('Hidden: ${r.hiddenReason}', style: Theme.of(context).textTheme.bodySmall),
                          ),
                      ],
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
