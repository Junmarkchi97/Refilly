import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';

/// Admin-only: review owner applications. Approval creates the station and makes the applicant an owner (SQL).
class AdminHome extends StatefulWidget {
  final Profile profile;
  const AdminHome({super.key, required this.profile});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  String _status = 'pending';
  bool _deciding = false;
  late Future<List<OwnerApplication>> _f = Api.applications(_status);

  void _reload() => setState(() => _f = Api.applications(_status));

  Future<void> _open(String path) async {
    try {
      final ok = await launchUrl(Uri.parse(await Api.docUrl(path)), mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Could not open document');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open document. Please try again.')));
    }
  }

  Future<void> _decide(OwnerApplication a, bool approve) async {
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(approve ? 'Approve ${a.stationName}?' : 'Reject ${a.stationName}?'),
        content: TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Notes (shown to applicant)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (ok != true || _deciding) return;
    setState(() => _deciding = true);
    try {
      approve ? await Api.approve(a.id, notes.text) : await Api.reject(a.id, notes.text);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the decision: $e')));
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owner applications'), actions: [logoutButton()]),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
            ],
            selected: {_status},
            onSelectionChanged: (s) {
              _status = s.first;
              _reload();
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<OwnerApplication>>(
            future: _f,
            builder: (context, snap) => StateSwitcher(
              child: KeyedSubtree(
                key: ValueKey(snap.hasData),
                child: Builder(
                  builder: (context) {
                    if (snap.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Unable to load applications'), const SizedBox(height: 12), FilledButton(onPressed: _reload, child: const Text('Retry'))]));
                    if (!snap.hasData) return const SkeletonList();
                    if (snap.data!.isEmpty) {
                      return EmptyState(
                        icon: _status == 'pending' ? Icons.inbox_rounded : Icons.folder_off_rounded,
                        title: _status == 'pending' ? 'All caught up' : 'Nothing here',
                        subtitle: _status == 'pending' ? 'No owner applications waiting for review.' : 'No $_status applications yet.',
                      );
                    }
                    return ListView(
                      children: [
                        for (final (aIdx, a) in (snap.data!).indexed)
                          FadeSlideIn(
                            index: aIdx,
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${a.stationName} — ${a.businessName}', style: Theme.of(context).textTheme.titleMedium),
                                    Text('${a.address} · ${a.phone ?? ''}'),
                                    Text('Pin: ${a.lat.toStringAsFixed(5)}, ${a.lng.toStringAsFixed(5)}'),
                                    if (a.notes != null) Text('Notes: ${a.notes}'),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton(onPressed: () => _open(a.permitPath), child: const Text('View permit')),
                                        TextButton(onPressed: () => _open(a.photoPath), child: const Text('View photo')),
                                        if (a.status == 'pending')
                                          FilledButton(onPressed: _deciding ? null : () => _decide(a, true), child: const Text('Approve')),
                                        if (a.status == 'pending')
                                          OutlinedButton(onPressed: _deciding ? null : () => _decide(a, false), child: const Text('Reject')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
