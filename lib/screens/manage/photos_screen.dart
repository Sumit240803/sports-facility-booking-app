import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  late Future<List<Photo>> _photos;
  bool _uploading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _photos = context.api.photos(widget.venue.id);

  Future<void> _upload() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 90, maxWidth: 2400, limit: 15);
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    final api = context.api;
    var done = 0;
    for (final f in files) {
      if (!mounted) return;
      final ok = await runAction(context, () => api.uploadPhoto(widget.venue.id, f.path));
      if (!ok) break;
      done++;
    }
    if (!mounted) return;
    if (done > 0) showMessage(context, 'Uploaded $done photo${done == 1 ? '' : 's'}');
    setState(() {
      _uploading = false;
      _load();
    });
  }

  Future<void> _actions(Photo p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!p.isCover)
            ListTile(leading: const Icon(Icons.star_outline), title: const Text('Set as cover'), onTap: () => Navigator.pop(context, 'cover')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    final api = context.api;
    final ok = await runAction(
      context,
      () => action == 'cover' ? api.setCoverPhoto(widget.venue.id, p.id) : api.deletePhoto(widget.venue.id, p.id),
    );
    if (ok && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.venue.canEdit;
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_uploading ? 'Uploading…' : 'Add photos'),
            )
          : null,
      body: AsyncView<List<Photo>>(
        future: _photos,
        onRetry: () => setState(_load),
        isEmpty: (p) => p.isEmpty,
        empty: const MessageView(
          icon: Icons.photo_library_outlined,
          title: 'No photos yet',
          message: 'Add at least one photo (min 400px). The first one becomes the cover.',
        ),
        builder: (context, photos) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: photos.length,
          itemBuilder: (context, i) {
            final p = photos[i];
            return GestureDetector(
              onTap: canEdit ? () => _actions(p) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  Image.network(p.thumbUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12)),
                  if (p.isCover)
                    const Positioned(left: 8, top: 8, child: Chip(label: Text('Cover'), visualDensity: VisualDensity.compact)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
