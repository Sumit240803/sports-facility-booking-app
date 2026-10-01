import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'reviews.dart';
import 'venue_detail_screen.dart';
import '../widgets/app_icons.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late Future<List<(Review, String, String)>> _reviews;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _reviews = context.api.myReviews();

  Future<void> _edit(Review r, String venueName) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WriteReviewSheet(venueId: r.venueId, venueName: venueName, existing: r),
    );
    if (changed == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
      body: AsyncView<List<(Review, String, String)>>(
        future: _reviews,
        onRetry: () => setState(_load),
        isEmpty: (r) => r.isEmpty,
        empty: const MessageView(
          icon: AppIcons.writeReview,
          title: 'No reviews yet',
          message: 'After you play, open the booking and tap "Rate this venue".',
        ),
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            final (review, venueName, slug) = list[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(venueName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: slug.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VenueDetailScreen(idOrSlug: slug, title: venueName),
                          ),
                        ),
                  trailing: IconButton(
                    tooltip: 'Edit',
                    icon: const AppIcon(AppIcons.edit),
                    onPressed: () => _edit(review, venueName),
                  ),
                ),
                ReviewTile(review: review),
                if (review.isHidden)
                  const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: StatusPill('hidden')),
              ],
            );
          },
        ),
      ),
    );
  }
}
