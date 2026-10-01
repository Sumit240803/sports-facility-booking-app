import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import 'favourites_screen.dart';
import 'manage/my_venues_screen.dart';
import 'my_reviews_screen.dart';
import 'owner_application_screen.dart';
import 'reminders_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    if (!await confirm(
      context,
      'Sign out?',
      message: 'You can sign back in with Google any time.',
      action: 'Sign out',
    )) {
      return;
    }
    if (!context.mounted) return;
    final session = context.session;
    final api = context.api;
    await context.push.stop();
    try {
      await api.logout();
    } catch (_) {
      // Sign out locally even if the server call fails.
    }
    await session.clear();
  }

  void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final store = context.profileStore;
    final theme = context.themeController;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, theme]),
        builder: (context, _) {
          final p = store.profile!;
          return RefreshIndicator(
            onRefresh: store.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _ProfileHeader(
                  profile: p,
                  onEdit: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: p)),
                    );
                    if (updated == true) store.load();
                  },
                ),

                const SectionTitle('Activity'),
                MenuCard(
                  children: [
                    MenuRow(
                      icon: AppIcons.favourite,
                      title: 'Favourites',
                      subtitle: 'Venues you saved',
                      color: AppColors.danger,
                      onTap: () => _push(context, const FavouritesScreen()),
                    ),
                    MenuRow(
                      icon: AppIcons.writeReview,
                      title: 'My reviews',
                      subtitle: 'Ratings you have given',
                      color: AppColors.pending,
                      onTap: () => _push(context, const MyReviewsScreen()),
                    ),
                    MenuRow(
                      icon: AppIcons.alarm,
                      title: 'Slot reminders',
                      subtitle: 'Get notified when booking opens',
                      onTap: () => _push(context, const RemindersScreen()),
                    ),
                  ],
                ),

                const SectionTitle('Notifications'),
                MenuCard(
                  children: [
                    MenuRow(
                      icon: AppIcons.notification,
                      title: 'Push notifications',
                      subtitle: 'Bookings, reminders and updates',
                      trailing: Switch(
                        value: p.notifyPush,
                        onChanged: (v) =>
                            runAction(context, () async => store.set(await context.api.setNotificationPrefs(push: v))),
                      ),
                    ),
                    MenuRow(
                      icon: AppIcons.mail,
                      title: 'Email notifications',
                      subtitle: p.email,
                      trailing: Switch(
                        value: p.notifyEmail,
                        onChanged: (v) =>
                            runAction(context, () async => store.set(await context.api.setNotificationPrefs(email: v))),
                      ),
                    ),
                  ],
                ),

                const SectionTitle('Appearance'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: AppIcon(AppIcons.phoneTheme, size: 18),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: AppIcon(AppIcons.sun, size: 18),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: AppIcon(AppIcons.moon, size: 18),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {theme.mode},
                      onSelectionChanged: (s) => theme.set(s.first),
                    ),
                  ),
                ),

                if (p.role == 'player') ...[
                  const SectionTitle('For venues'),
                  MenuCard(
                    children: [
                      MenuRow(
                        icon: AppIcons.addVenue,
                        title: 'List your venue',
                        subtitle: 'Own a turf or court? Apply to become a partner',
                        onTap: () => _push(context, const OwnerApplicationScreen()),
                      ),
                      MenuRow(
                        icon: AppIcons.idCard,
                        title: 'Venues I work at',
                        subtitle: 'Front desk access from venue owners',
                        onTap: () => _push(context, const MyVenuesScreen(standalone: true)),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                MenuCard(
                  children: [
                    MenuRow(
                      icon: AppIcons.logout,
                      title: 'Sign out',
                      color: Theme.of(context).colorScheme.error,
                      onTap: () => _logout(context),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});
  final Profile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = profile;
    final name = p.fullName ?? p.email ?? 'Player';

    Widget fact(AppIconData icon, String value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 16, color: scheme.onPrimaryContainer),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ),
      ],
    );

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primary,
                  foregroundImage: p.avatarUrl != null ? CachedNetworkImageProvider(p.avatarUrl!) : null,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: text.headlineSmall?.copyWith(color: scheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: text.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          titleCase(p.role),
                          style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(tooltip: 'Edit profile', onPressed: onEdit, icon: const AppIcon(AppIcons.edit)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (p.phone != null) fact(AppIcons.phone, p.phone!),
                if (p.city != null) fact(AppIcons.location, p.city!),
                if (p.preferredSports.isNotEmpty) fact(AppIcons.racket, p.preferredSports.map(titleCase).join(', ')),
              ],
            ),
          ],
        ),
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
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: AppIcon(AppIcons.user)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              hintText: '+919876543210',
              prefixIcon: AppIcon(AppIcons.phone),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City', prefixIcon: AppIcon(AppIcons.city)),
          ),
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
