import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

/// Apply to list venues, or see the status of an existing application.
class OwnerApplicationScreen extends StatefulWidget {
  const OwnerApplicationScreen({super.key});

  @override
  State<OwnerApplicationScreen> createState() => _OwnerApplicationScreenState();
}

class _OwnerApplicationScreenState extends State<OwnerApplicationScreen> {
  late Future<OwnerApplication?> _app;
  final _form = GlobalKey<FormState>();
  final _business = TextEditingController();
  late final _phone = TextEditingController(text: context.profileStore.profile?.phone);
  final _gstin = TextEditingController();
  bool _editing = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _app = context.api.myOwnerApplication();

  @override
  void dispose() {
    _business.dispose();
    _phone.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => context.api.applyAsOwner(
        _business.text.trim(),
        _phone.text.replaceAll(' ', ''),
        _gstin.text.trim().toUpperCase(),
      ),
      success: 'Application submitted',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _editing = false;
        _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List your venue')),
      body: AsyncView<OwnerApplication?>(
        future: _app,
        onRetry: () => setState(_load),
        builder: (context, app) {
          if (app != null && !_editing) return _status(app);
          return _formView(reapplying: app != null);
        },
      ),
    );
  }

  Widget _status(OwnerApplication app) {
    final (icon, title, message) = switch (app.status) {
      'approved' => (Icons.verified, 'You\'re approved!', 'Tap "Refresh my access" to unlock the Manage tab.'),
      'rejected' => (Icons.cancel_outlined, 'Application rejected', app.rejectionReason ?? 'No reason given.'),
      _ => (Icons.hourglass_top, 'Application under review', 'We\'ll notify you once an admin reviews it.'),
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        MessageView(icon: icon, title: title, message: message),
        Card(
          child: Column(
            children: [
              ListTile(title: const Text('Business'), subtitle: Text(app.businessName)),
              ListTile(title: const Text('Phone'), subtitle: Text(app.businessPhone)),
              if (app.gstin != null) ListTile(title: const Text('GSTIN'), subtitle: Text(app.gstin!)),
              ListTile(title: const Text('Status'), trailing: StatusPill(app.status)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (app.status == 'rejected')
          FilledButton(onPressed: () => setState(() => _editing = true), child: const Text('Apply again')),
        if (app.status == 'approved')
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await context.profileStore.load();
              nav.pop();
            },
            child: const Text('Refresh my access'),
          ),
      ],
    );
  }

  Widget _formView({required bool reapplying}) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Own a turf, court or ground? Apply to list it on EasyPlay. An admin will verify your details.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _business,
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            decoration: const InputDecoration(labelText: 'Business name', prefixIcon: Icon(Icons.business)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            validator: (v) => RegExp(r'^\+[1-9]\d{7,14}$').hasMatch((v ?? '').replaceAll(' ', ''))
                ? null
                : 'Use international format, e.g. +919876543210',
            decoration: const InputDecoration(labelText: 'Business phone', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _gstin,
            textCapitalization: TextCapitalization.characters,
            validator: (v) {
              final s = (v ?? '').trim().toUpperCase();
              if (s.isEmpty) return null;
              return RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(s) ? null : 'Invalid GSTIN';
            },
            decoration: const InputDecoration(labelText: 'GSTIN (optional)', prefixIcon: Icon(Icons.receipt_long)),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(reapplying ? 'Re-apply' : 'Submit application')),
        ],
      ),
    );
  }
}
