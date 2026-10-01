import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../explore_screen.dart';
import '../manage/venue_manage_screen.dart';
import '../../widgets/app_icons.dart';

/// Admin review queues: owner applications and venues.
class AdminQueuesScreen extends StatelessWidget {
  const AdminQueuesScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Approvals & venues'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Owners'),
              Tab(text: 'Venue review'),
              Tab(text: 'All venues'),
            ],
          ),
        ),
        body: const TabBarView(children: [_OwnerApplications(), _VenueQueue(), _AllVenues()]),
      ),
    );
  }
}

class _OwnerApplications extends StatefulWidget {
  const _OwnerApplications();

  @override
  State<_OwnerApplications> createState() => _OwnerApplicationsState();
}

class _OwnerApplicationsState extends State<_OwnerApplications> with AutomaticKeepAliveClientMixin {
  String _status = 'pending';
  late Future<List<OwnerApplication>> _apps;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _apps = context.api.ownerApplications(_status);

  Future<void> _approve(OwnerApplication a) async {
    if (!await confirm(
      context,
      'Approve ${a.businessName}?',
      message: 'They become a venue owner.',
      action: 'Approve',
    )) {
      return;
    }
    if (!mounted) return;
    if (await runAction(context, () => context.api.approveOwner(a.userId), success: 'Approved')) setState(_load);
  }

  Future<void> _reject(OwnerApplication a) async {
    final reason = await promptText(
      context,
      'Reject ${a.businessName}',
      label: 'Reason (shown to the applicant)',
      action: 'Reject',
    );
    if (reason == null || !mounted) return;
    if (await runAction(context, () => context.api.rejectOwner(a.userId, reason), success: 'Rejected')) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _StatusFilter(
          options: const ['pending', 'approved', 'rejected'],
          value: _status,
          onChanged: (s) => setState(() {
            _status = s;
            _load();
          }),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _apps;
            },
            child: AsyncView<List<OwnerApplication>>(
              future: _apps,
              onRetry: () => setState(_load),
              isEmpty: (a) => a.isEmpty,
              empty: ListView(
                children: const [
                  SizedBox(height: 60),
                  MessageView(icon: AppIcons.inbox, title: 'Nothing here'),
                ],
              ),
              builder: (context, apps) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: apps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = apps[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(a.businessName, style: Theme.of(context).textTheme.titleMedium)),
                              StatusPill(a.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text([a.applicantName, a.applicantEmail].whereType<String>().join(' · ')),
                          Text('Business phone: ${a.businessPhone}${a.gstin != null ? ' · GSTIN ${a.gstin}' : ''}'),
                          if (a.rejectionReason != null) Text('Reason: ${a.rejectionReason}'),
                          if (a.status == 'pending')
                            OverflowBar(
                              alignment: MainAxisAlignment.end,
                              children: [
                                TextButton(onPressed: () => _reject(a), child: const Text('Reject')),
                                FilledButton(onPressed: () => _approve(a), child: const Text('Approve')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VenueQueue extends StatelessWidget {
  const _VenueQueue();

  @override
  Widget build(BuildContext context) => const _VenueList(statuses: ['pending_review']);
}

class _AllVenues extends StatelessWidget {
  const _AllVenues();

  @override
  Widget build(BuildContext context) => const _VenueList(statuses: ['live', 'suspended', 'rejected', 'draft']);
}

class _VenueList extends StatefulWidget {
  const _VenueList({required this.statuses});
  final List<String> statuses;

  @override
  State<_VenueList> createState() => _VenueListState();
}

class _VenueListState extends State<_VenueList> with AutomaticKeepAliveClientMixin {
  late String _status = widget.statuses.first;
  late Future<List<VenueSummary>> _venues;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() => _venues = context.api.adminVenues(_status);

  Future<void> _act(VenueSummary v, String action) async {
    final api = context.api;
    Future<void> Function()? call;
    switch (action) {
      case 'approve':
        if (!await confirm(context, 'Approve ${v.name}?', message: 'It goes live for players.', action: 'Approve')) {
          return;
        }
        call = () => api.approveVenue(v.id);
      case 'reinstate':
        if (!await confirm(context, 'Reinstate ${v.name}?', action: 'Reinstate')) return;
        call = () => api.reinstateVenue(v.id);
      case 'reject' || 'suspend':
        if (!mounted) return;
        final reason = await promptText(
          context,
          '${titleCaseWord(action)} ${v.name}',
          label: action == 'suspend' ? 'Reason (upcoming bookings are cancelled and refunded)' : 'Reason for the owner',
          action: titleCaseWord(action),
        );
        if (reason == null) return;
        call = action == 'reject' ? () => api.rejectVenue(v.id, reason) : () => api.suspendVenue(v.id, reason);
    }
    if (!mounted || call == null) return;
    if (await runAction(context, call, success: 'Done')) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        if (widget.statuses.length > 1)
          _StatusFilter(
            options: widget.statuses,
            value: _status,
            onChanged: (s) => setState(() {
              _status = s;
              _load();
            }),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _venues;
            },
            child: AsyncView<List<VenueSummary>>(
              future: _venues,
              onRetry: () => setState(_load),
              isEmpty: (v) => v.isEmpty,
              empty: ListView(
                children: const [
                  SizedBox(height: 60),
                  MessageView(icon: AppIcons.inbox, title: 'Nothing here'),
                ],
              ),
              builder: (context, venues) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: venues.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final v = venues[i];
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => VenueManageScreen(venueId: v.id)),
                          ).then((_) => setState(_load)),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox.square(dimension: 48, child: VenueImage(url: v.coverUrl)),
                          ),
                          title: Text(v.name),
                          subtitle: Text(
                            [
                              v.place,
                              if (v.statusReason != null) v.statusReason!,
                            ].where((s) => s.isNotEmpty).join('\n'),
                          ),
                          trailing: StatusPill(v.status),
                        ),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          children: [
                            if (v.status == 'pending_review') ...[
                              TextButton(onPressed: () => _act(v, 'reject'), child: const Text('Reject')),
                              FilledButton(onPressed: () => _act(v, 'approve'), child: const Text('Approve')),
                            ],
                            if (v.status == 'live')
                              TextButton(onPressed: () => _act(v, 'suspend'), child: const Text('Suspend')),
                            if (v.status == 'suspended')
                              FilledButton.tonal(onPressed: () => _act(v, 'reinstate'), child: const Text('Reinstate')),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String titleCaseWord(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.replaceAll('_', ' ')),
                selected: o == value,
                onSelected: (_) => onChanged(o),
              ),
            ),
        ],
      ),
    );
  }
}
