import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

/// Rating summary + latest reviews, shown on the venue page.
class VenueReviewsSection extends StatefulWidget {
  const VenueReviewsSection({super.key, required this.venueId, required this.venueName});
  final String venueId;
  final String venueName;

  @override
  State<VenueReviewsSection> createState() => _VenueReviewsSectionState();
}

class _VenueReviewsSectionState extends State<VenueReviewsSection> {
  late Future<ReviewPage> _page;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _page = context.api.venueReviews(widget.venueId, limit: 3);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReviewPage>(
      future: _page,
      builder: (context, snap) {
        final page = snap.data;
        if (page == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'Reviews (${page.total})',
              trailing: page.total > page.reviews.length
                  ? TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllReviewsScreen(venueId: widget.venueId, venueName: widget.venueName),
                        ),
                      ),
                      child: const Text('See all'),
                    )
                  : null,
            ),
            if (page.total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('No reviews yet. Players can review after they play here.'),
              )
            else ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: RatingBreakdown(page: page)),
              for (final r in page.reviews) ReviewTile(review: r),
            ],
          ],
        );
      },
    );
  }
}

class RatingBreakdown extends StatelessWidget {
  const RatingBreakdown({super.key, required this.page});
  final ReviewPage page;

  @override
  Widget build(BuildContext context) {
    final total = page.breakdown.values.fold<int>(0, (a, b) => a + b);
    final avg = total == 0 ? 0.0 : page.breakdown.entries.fold<int>(0, (a, e) => a + e.key * e.value) / total;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Column(
          children: [
            Text(avg.toStringAsFixed(1), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
            Stars(avg.round()),
            Text('$total ratings', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              for (var star = 5; star >= 1; star--)
                Row(
                  children: [
                    SizedBox(width: 14, child: Text('$star', style: Theme.of(context).textTheme.labelSmall)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (page.breakdown[star] ?? 0) / total,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        color: scheme.tertiary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.trailing});
  final Review review;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                foregroundImage: review.authorAvatar != null ? NetworkImage(review.authorAvatar!) : null,
                child: Text(review.authorName.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName, style: text.titleSmall),
                    Row(children: [
                      Stars(review.rating, size: 14),
                      const SizedBox(width: 6),
                      Text(DateFormat('d MMM yyyy').format(DateTime.parse(review.createdAt).toLocal()),
                          style: text.labelSmall),
                      if (review.isHidden) ...[const SizedBox(width: 6), const StatusPill('hidden')],
                    ]),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (review.comment?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(review.comment!),
          ],
          if (review.ownerReply != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reply from the venue', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(review.ownerReply!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AllReviewsScreen extends StatefulWidget {
  const AllReviewsScreen({super.key, required this.venueId, required this.venueName});
  final String venueId;
  final String venueName;

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  String _sort = 'newest';
  late Future<ReviewPage> _page;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _page = context.api.venueReviews(widget.venueId, sort: _sort, limit: 50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.venueName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() {
              _sort = s;
              _load();
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'newest', child: Text('Newest')),
              PopupMenuItem(value: 'highest', child: Text('Highest rated')),
              PopupMenuItem(value: 'lowest', child: Text('Lowest rated')),
            ],
          ),
        ],
      ),
      body: AsyncView<ReviewPage>(
        future: _page,
        onRetry: () => setState(_load),
        builder: (context, page) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(padding: const EdgeInsets.all(16), child: RatingBreakdown(page: page)),
            const Divider(),
            for (final r in page.reviews) ReviewTile(review: r),
          ],
        ),
      ),
    );
  }
}

/// Write or edit the player's review of a venue. Pops `true` when saved or deleted.
class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({super.key, required this.venueId, required this.venueName, this.existing});
  final String venueId;
  final String venueName;
  final Review? existing;

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment);
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final ok = await runAction(
      context,
      () => context.api.saveReview(widget.venueId, _rating, _comment.text.trim()),
      success: 'Thanks for your review!',
    );
    if (ok) {
      nav.pop(true);
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    if (!await confirm(context, 'Delete your review?', action: 'Delete')) return;
    if (!mounted) return;
    if (await runAction(context, () => context.api.deleteReview(widget.venueId))) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rate ${widget.venueName}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: scheme.tertiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Tell other players about the courts, staff, facilities…'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy || _rating == 0 ? null : _save, child: const Text('Submit review')),
          if (widget.existing != null)
            TextButton(onPressed: _busy ? null : _delete, child: const Text('Delete review')),
        ],
      ),
    );
  }
}
