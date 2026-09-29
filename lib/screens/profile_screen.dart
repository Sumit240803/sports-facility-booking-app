import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../data/models.dart';
import 'favourites_screen.dart';
import 'manage/my_venues_screen.dart';
import 'owner_application_screen.dart';
import 'reminders_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final session = context.session;
    try {
      await context.api.logout();
    } catch (_) {
      // Sign out locally even if the server call fails.
    }
    await session.clear();
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final store = context.profileStore;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final p = store.profile!;
          final name = p.fullName ?? p.email ?? 'Player';
          return RefreshIndicator(
            onRefresh: store.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: scheme.primaryContainer,
                    foregroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                    child: Text(name.characters.first.toUpperCase(),
                        style: text.headlineMedium?.copyWith(color: scheme.onPrimaryContainer)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, textAlign: TextAlign.center, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (p.email != null)
                  Text(p.email!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Center(child: Chip(label: Text(titleCase(p.role)), visualDensity: VisualDensity.compact)),
                const SizedBox(height: 16),
                Card(
                  child: Column(children: [
                    ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('Phone'), subtitle: Text(p.phone ?? 'Not set')),
                    ListTile(leading: const Icon(Icons.location_city), title: const Text('City'), subtitle: Text(p.city ?? 'Not set')),
                    ListTile(
                      leading: const Icon(Icons.sports_soccer),
                      title: const Text('Favourite sports'),
                      subtitle: Text(p.preferredSports.isEmpty ? 'Not set' : p.preferredSports.map(titleCase).join(', ')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => EditProfileScreen(profile: p)),
                        );
                        if (updated == true) store.load();
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.favorite_border),
                      title: const Text('Favourites'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const FavouritesScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.alarm),
                      title: const Text('Slot reminders'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const RemindersScreen()),
                    ),
                    if (p.role == 'player') ...[
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Venues I work at'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _push(context, const MyVenuesScreen(standalone: true)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_business_outlined),
                        title: const Text('List your venue'),
                        subtitle: const Text('Apply to become a venue owner'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _push(context, const OwnerApplicationScreen()),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final Profile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _city = TextEditingController(text: widget.profile.city);
  late final Set<String> _sports = {...widget.profile.preferredSports};
  List<CatalogItem> _allSports = const [];
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allSports.isEmpty) {
      context.api.sports().then((s) => mounted ? setState(() => _allSports = s) : null).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.api.updateMe(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        city: _city.text.trim(),
        preferredSports: _sports.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', hintText: '+919876543210', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city))),
          const SizedBox(height: 20),
          Text('Favourite sports', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _allSports)
                FilterChip(
                  label: Text(s.name),
                  selected: _sports.contains(s.id),
                  onSelected: (on) => setState(() => on ? _sports.add(s.id) : _sports.remove(s.id)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
