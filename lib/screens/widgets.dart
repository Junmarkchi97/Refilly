import 'package:flutter/material.dart';
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

IconButton logoutButton() => IconButton(icon: const Icon(Icons.logout), onPressed: () => sb.auth.signOut());

Color statusColor(String s) => switch (s) {
      'pending' => Colors.orange,
      'accepted' || 'preparing' => Colors.blue,
      'out_for_delivery' => Colors.purple,
      'delivered' => Colors.green,
      _ => Colors.grey,
    };
