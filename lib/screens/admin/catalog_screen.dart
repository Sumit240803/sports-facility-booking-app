import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// Sports and amenities offered to owners (courts, venue amenities) and players (filters).
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _CatalogAppBar(),
        body: TabBarView(
          children: [
            _CatalogList(table: 'sports'),
            _CatalogList(table: 'amenities'),
          ],
        ),
      ),
    );
  }
}

class _CatalogAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CatalogAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: const Text('Sports & amenities'),
    bottom: const TabBar(
      tabs: [
        Tab(text: 'Sports'),
        Tab(text: 'Amenities'),
      ],
    ),
  );
}

class _CatalogList extends StatefulWidget {
  const _CatalogList({required this.table});
  final String table;

  @override
  State<_CatalogList> createState() => _CatalogListState();
}

class _CatalogListState extends State<_CatalogList> with AutomaticKeepAliveClientMixin {
  late Future<List<AdminCatalogItem>> _items;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _items = context.api.adminCatalog(widget.table);

  String get _noun => widget.table == 'sports' ? 'sport' : 'amenity';

  Future<void> _add(List<AdminCatalogItem> existing) async {
    final name = await promptText(
      context,
      'New $_noun',
      label: 'Name, e.g. ${widget.table == 'sports' ? 'Padel' : 'Power backup'}',
      action: 'Add',
    );
    if (name == null || !mounted) return;
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (id.isEmpty) return;
    final next = existing.isEmpty ? 1 : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    if (await runAction(
      context,
      () => context.api.createCatalogItem(widget.table, id, name, next),
      success: 'Added $name',
    )) {
      setState(_load);
    }
  }

  Future<void> _rename(AdminCatalogItem item) async {
    final name = await promptText(context, 'Rename', initial: item.name);
    if (name == null || name == item.name || !mounted) return;
    if (await runAction(context, () => context.api.updateCatalogItem(widget.table, item.id, name: name))) {
      setState(_load);
    }
  }

  Future<void> _toggle(AdminCatalogItem item, bool active) async {
    if (await runAction(context, () => context.api.updateCatalogItem(widget.table, item.id, isActive: active))) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AsyncView<List<AdminCatalogItem>>(
      future: _items,
      onRetry: () => setState(_load),
      builder: (context, items) => Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Inactive items are hidden from new venues and filters; existing data keeps them.'),
              ),
              for (final item in items)
                SwitchListTile(
                  title: Text(item.name),
                  subtitle: Text(item.id),
                  value: item.isActive,
                  onChanged: (v) => _toggle(item, v),
                  secondary: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _rename(item)),
                ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: widget.table,
              onPressed: () => _add(items),
              icon: const Icon(Icons.add),
              label: Text('Add $_noun'),
            ),
          ),
        ],
      ),
    );
  }
}
