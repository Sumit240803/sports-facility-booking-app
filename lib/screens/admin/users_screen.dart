import 'package:cached_network_image/cached_network_image.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/app_icons.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _q = '';
  String? _role;
  String? _status;
  Timer? _debounce;
  late Future<List<AdminUser>> _users;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _users = context.api.adminUsers(q: _q.trim(), role: _role, status: _status);

  void _reload() => setState(_load);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _manage(AdminUser u) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => _UserSheet(user: u),
    );
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.profileStore.profile?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: 'Email, name or phone',
              leading: const AppIcon(AppIcons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) {
                _q = v;
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _reload);
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final r in [null, 'player', 'venue_owner', 'admin'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r == null ? 'All roles' : titleCase(r)),
                      selected: _role == r,
                      onSelected: (_) {
                        _role = r;
                        _reload();
                      },
                    ),
                  ),
                FilterChip(
                  label: const Text('Suspended'),
                  selected: _status == 'suspended',
                  onSelected: (on) {
                    _status = on ? 'suspended' : null;
                    _reload();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<AdminUser>>(
              future: _users,
              onRetry: _reload,
              isEmpty: (u) => u.isEmpty,
              empty: const MessageView(icon: AppIcons.userSearch, title: 'No users found'),
              builder: (context, users) => ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = users[i];
                  return ListTile(
                    onTap: u.id == me ? null : () => _manage(u),
                    leading: CircleAvatar(
                      foregroundImage: u.avatarUrl != null ? CachedNetworkImageProvider(u.avatarUrl!) : null,
                      child: Text(u.display.characters.first.toUpperCase()),
                    ),
                    title: Text(u.id == me ? '${u.display} (you)' : u.display),
                    subtitle: Text([u.email, u.phone, u.city].whereType<String>().join(' · ')),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(titleCase(u.role), style: Theme.of(context).textTheme.labelMedium),
                        if (u.status == 'suspended') const StatusPill('suspended'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSheet extends StatelessWidget {
  const _UserSheet({required this.user});
  final AdminUser user;

  Future<void> _update(BuildContext context, {String? role, String? status}) async {
    final nav = Navigator.of(context);
    final what = role != null
        ? 'Make ${user.display} ${titleCase(role).toLowerCase()}?'
        : '${status == 'suspended' ? 'Suspend' : 'Reactivate'} ${user.display}?';
    final message = status == 'suspended'
        ? 'They are signed out everywhere and can\'t sign in or book until reactivated.'
        : role == 'player'
        ? 'They lose access to venue management (their venues stay).'
        : null;
    if (!await confirm(context, what, message: message)) return;
    if (!context.mounted) return;
    if (await runAction(
      context,
      () => context.api.updateUser(user.id, role: role, status: status),
      success: 'User updated',
    )) {
      nav.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = DateFormat('d MMM yyyy').format(DateTime.parse(user.createdAt).toLocal());
    final lastSeen = user.lastLoginAt == null
        ? 'never'
        : DateFormat('d MMM, h:mm a').format(DateTime.parse(user.lastLoginAt!).toLocal());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(user.display, style: Theme.of(context).textTheme.titleLarge),
            Text('Joined $joined · last sign-in $lastSeen', style: Theme.of(context).textTheme.bodySmall),
            const SectionTitle('Role'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'player', label: Text('Player')),
                ButtonSegment(value: 'venue_owner', label: Text('Owner')),
                ButtonSegment(value: 'admin', label: Text('Admin')),
              ],
              selected: {user.role},
              onSelectionChanged: (s) => _update(context, role: s.first),
            ),
            const SizedBox(height: 20),
            if (user.status == 'suspended')
              FilledButton.icon(
                onPressed: () => _update(context, status: 'active'),
                icon: const AppIcon(AppIcons.unlock),
                label: const Text('Reactivate'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _update(context, status: 'suspended'),
                icon: const AppIcon(AppIcons.block),
                label: const Text('Suspend'),
              ),
          ],
        ),
      ),
    );
  }
}
