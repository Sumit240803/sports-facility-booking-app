import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key, required this.venue});
  final ManagedVenue venue;

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<(List<StaffMember>, List<StaffInvite>)> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _data = context.api.staff(widget.venue.id);

  Future<void> _invite() async {
    final result = await showDialog<(String, String)>(context: context, builder: (_) => const _InviteDialog());
    if (result == null || !mounted) return;
    if (await runAction(
      context,
      () => context.api.inviteStaff(widget.venue.id, result.$1, result.$2),
      success: 'Invited ${result.$1}',
    )) {
      setState(_load);
    }
  }

  Future<void> _remove(StaffMember m) async {
    if (!await confirm(context, 'Remove ${m.name}?', action: 'Remove')) return;
    if (!mounted) return;
    if (await runAction(context, () => context.api.removeStaff(widget.venue.id, m.userId))) setState(_load);
  }

  Future<void> _cancelInvite(StaffInvite i) async {
    if (await runAction(context, () => context.api.cancelInvite(widget.venue.id, i.email))) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.venue.isOwner;
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(onPressed: _invite, icon: const Icon(Icons.person_add), label: const Text('Invite'))
          : null,
      body: AsyncView<(List<StaffMember>, List<StaffInvite>)>(
        future: _data,
        onRetry: () => setState(_load),
        isEmpty: (d) => d.$1.isEmpty && d.$2.isEmpty,
        empty: const MessageView(
          icon: Icons.group_outlined,
          title: 'No staff yet',
          message: 'Managers can edit courts, hours and prices. Staff handle the front desk.',
        ),
        builder: (context, d) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (d.$1.isNotEmpty) const SectionTitle('Team'),
            for (final m in d.$1)
              ListTile(
                leading: CircleAvatar(child: Text(m.name.characters.first.toUpperCase())),
                title: Text(m.name),
                subtitle: Text('${titleCase(m.role)}${m.email != null ? ' · ${m.email}' : ''}'),
                trailing: isOwner
                    ? IconButton(icon: const Icon(Icons.person_remove_outlined), onPressed: () => _remove(m))
                    : null,
              ),
            if (d.$2.isNotEmpty) const SectionTitle('Pending invites'),
            for (final i in d.$2)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.mail_outline)),
                title: Text(i.email),
                subtitle: Text('${titleCase(i.role)} · joins on first sign-in'),
                trailing: isOwner ? IconButton(icon: const Icon(Icons.close), onPressed: () => _cancelInvite(i)) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  String _role = 'staff';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
    return AlertDialog(
      title: const Text('Invite staff'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'staff', label: Text('Staff')),
              ButtonSegment(value: 'manager', label: Text('Manager')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, (_email.text.trim(), _role)) : null,
          child: const Text('Invite'),
        ),
      ],
    );
  }
}
