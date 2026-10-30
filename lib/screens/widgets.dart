import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';

const manila = LatLng(14.5995, 120.9842);
String peso(num v) => '₱${v.toStringAsFixed(2)}';

TileLayer osmTiles() => TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: AppConfig.userAgent);

Widget osmAttribution() => const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]);

Marker pin(LatLng p, IconData icon, Color color, {VoidCallback? onTap}) => Marker(
      point: p,
      width: 44,
      height: 44,
      child: GestureDetector(onTap: onTap, child: Icon(icon, color: color, size: 40)),
    );

/// Copy or share (SMS / Messenger share sheet) a rider delivery link.
Future<void> shareRiderLink(BuildContext context, String link, String riderName) => showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('Delivery link for $riderName'), subtitle: SelectableText(link)),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy link'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (c.mounted) Navigator.pop(c);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share (SMS, Messenger…)'),
            onTap: () async {
              await SharePlus.instance.share(ShareParams(text: 'Refilly delivery for $riderName: $link'));
              if (c.mounted) Navigator.pop(c);
            },
          ),
        ]),
      ),
    );

IconButton logoutButton() => IconButton(icon: const Icon(Icons.logout), onPressed: () => sb.auth.signOut());

Color statusColor(String s) => switch (s) {
      'pending' => Colors.orange,
      'accepted' || 'preparing' => Colors.blue,
      'out_for_delivery' => Colors.purple,
      'delivered' => Colors.green,
      _ => Colors.grey,
    };
