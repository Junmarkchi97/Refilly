import 'package:flutter/material.dart';
import '../services/api.dart';

/// Private in-app order notifications. External FCM push requires additional provider setup.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _items = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await sb.from('user_notifications').select().order('created_at', ascending: false).limit(100),
      );

  void _refresh() => setState(() => _items = _load());

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) { return; }
    try {
      await sb.from('user_notifications').update({'is_read': true}).eq('id', item['id']);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to mark notification as read.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications'), actions: [
      IconButton(tooltip: 'Refresh notifications', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications unavailable'),
            const SizedBox(height: 10),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ));
        if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
        final entries = snapshot.data!;
        if (entries.isEmpty) { return const Center(child: Text('No notifications yet')); }
        return RefreshIndicator(
          onRefresh: () async { _refresh(); await _items; },
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final n = entries[index];
              final unread = n['is_read'] != true;
              return ListTile(
                leading: Icon(unread ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                title: Text(n['title']?.toString() ?? 'Order update', style: TextStyle(
                  fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(n['body']?.toString() ?? ''),
                trailing: unread ? const Icon(Icons.circle, size: 10) : null,
                onTap: () => _markRead(n),
              );
            },
          ),
        );
      },
    ),
  );
}
