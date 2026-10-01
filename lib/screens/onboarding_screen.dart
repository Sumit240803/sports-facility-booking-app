import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/app_icons.dart';

/// Shown after the first sign-in until name, phone and city are set.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  late final Profile _p = context.profileStore.profile!;
  late final _name = TextEditingController(text: _p.fullName);
  late final _phone = TextEditingController(text: _p.phone ?? '+91');
  late final _city = TextEditingController(text: _p.city);
  final Set<String> _sports = {};
  List<CatalogItem> _allSports = const [];
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allSports.isEmpty) {
      context.api
          .sports()
          .then((s) {
            if (mounted) setState(() => _allSports = s);
          })
          .catchError((_) {});
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
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final store = context.profileStore;
    await runAction(context, () async {
      final updated = await context.api.updateMe(
        fullName: _name.text.trim(),
        phone: _phone.text.replaceAll(' ', ''),
        city: _city.text.trim(),
        preferredSports: _sports.toList(),
      );
      store.set(updated);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Welcome to ZocoPlay', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Tell us a little about yourself to start booking.', style: text.bodyLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                validator: required,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: AppIcon(AppIcons.user)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: (v) => RegExp(r'^\+[1-9]\d{7,14}$').hasMatch((v ?? '').replaceAll(' ', ''))
                    ? null
                    : 'Use international format, e.g. +919876543210',
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: AppIcon(AppIcons.phone)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                validator: required,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'City', prefixIcon: AppIcon(AppIcons.city)),
              ),
              if (_allSports.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Sports you play', style: text.titleSmall),
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
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continue'),
              ),
              TextButton(
                onPressed: () async {
                  final session = context.session;
                  await context.push.stop();
                  await session.clear();
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
