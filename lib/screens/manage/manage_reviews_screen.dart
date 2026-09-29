import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../reviews.dart';

class ManageReviewsScreen extends StatefulWidget {
  const ManageReviewsScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<ManageReviewsScreen> createState() => _ManageReviewsScreenState();
}

class _ManageReviewsScreenState extends State<ManageReviewsScreen> {
  late Future<ReviewPage> _page;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _page = context.api.manageReviews(widget.venue.id);

  Future<void> _reply(Review r) async {
    final text = await promptText(context, 'Reply to ${r.authorName}', initial: r.ownerReply, action: 'Post reply', maxLines: 4);
    if (text == null || !mounted) return;
    if (await runAction(context, () => context.api.replyToReview(widget.venue.id, r.id, text), success: 'Reply posted')) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: AsyncView<ReviewPage>(
        future: _page,
        onRetry: () => setState(_load),
        isEmpty: (p) => p.reviews.isEmpty,
        empty: const MessageView(icon: Icons.reviews_outlined, title: 'No reviews yet'),
        builder: (context, page) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(padding: const EdgeInsets.all(16), child: RatingBreakdown(page: page)),
            const Divider(),
            for (final r in page.reviews)
              ReviewTile(
                review: r,
                trailing: widget.venue.canEdit
                    ? IconButton(
                        tooltip: r.ownerReply == null ? 'Reply' : 'Edit reply',
                        icon: const Icon(Icons.reply),
                        onPressed: () => _reply(r),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
