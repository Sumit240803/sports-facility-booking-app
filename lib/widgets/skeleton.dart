import 'package:flutter/material.dart';

/// Pulsing placeholder shown while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// A list of card-shaped skeletons. [image] adds a large image block (venue cards).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.image = false});
  final int count;
  final bool image;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image) const AspectRatio(aspectRatio: 16 / 9, child: Skeleton(radius: 0)),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 180, height: 18),
                  SizedBox(height: 10),
                  Skeleton(width: 240),
                  SizedBox(height: 10),
                  Skeleton(width: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
