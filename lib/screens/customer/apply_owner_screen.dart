import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';

/// Customers apply to become station owners; an admin reviews the documents.
class ApplyOwnerScreen extends StatefulWidget {
  const ApplyOwnerScreen({super.key});
  @override
  State<ApplyOwnerScreen> createState() => _ApplyOwnerScreenState();
}

class _ApplyOwnerScreenState extends State<ApplyOwnerScreen> {
  late Future<List<OwnerApplication>> _mine = Api.myApplications();
  final _biz = TextEditingController(),
      _station = TextEditingController(),
      _addr = TextEditingController(),
      _phone = TextEditingController();
  LatLng _pt = manila;
  PlatformFile? _permit, _photo;
  bool _busy = false;

  Future<PlatformFile?> _pick(List<String> ext) async =>
      (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ext)).firstOrNull;

  String _mime(String n) => switch (n.split('.').last.toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  Future<void> _submit() async {
    if ([_biz, _station, _addr].any((c) => c.text.trim().isEmpty) || _permit == null || _photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill in all fields and attach both files')));
      return;
    }
    setState(() => _busy = true);
    try {
      final permit = await Api.uploadDoc('permit_${_permit!.name}', await _permit!.readAsBytes(), _mime(_permit!.name));
      final photo = await Api.uploadDoc('photo_${_photo!.name}', await _photo!.readAsBytes(), _mime(_photo!.name));
      await Api.submitApplication({
        'business_name': _biz.text.trim(),
        'station_name': _station.text.trim(),
        'address': _addr.text.trim(),
        'phone': _phone.text.trim(),
        'lat': _pt.latitude,
        'lng': _pt.longitude,
        'permit_path': permit,
        'photo_path': photo,
      });
      setState(() => _mine = Api.myApplications());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Become a station owner')),
    body: FutureBuilder<List<OwnerApplication>>(
      future: _mine,
      builder: (context, snap) {
        if (!snap.hasData) return const SkeletonList();
        final pending = snap.data!.where((a) => a.status == 'pending').firstOrNull;
        final last = snap.data!.firstOrNull;
        if (pending != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Your application for "${pending.stationName}" is under review. You will become an owner once approved (log out and in again).',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (last?.status == 'rejected')
              Card(
                child: ListTile(title: const Text('Previous application rejected'), subtitle: Text(last!.notes ?? '')),
              ),
            TextField(
              controller: _biz,
              decoration: const InputDecoration(labelText: 'Registered business name'),
            ),
            TextField(
              controller: _station,
              decoration: const InputDecoration(labelText: 'Station name'),
            ),
            TextField(
              controller: _addr,
              decoration: const InputDecoration(labelText: 'Station address'),
            ),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Station phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(_permit?.name ?? 'DTI/SEC registration or business permit'),
              trailing: const Icon(Icons.attach_file),
              onTap: () async {
                final f = await _pick(['pdf', 'jpg', 'jpeg', 'png', 'webp']);
                if (f != null) setState(() => _permit = f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: Text(_photo?.name ?? 'Photo of your station'),
              trailing: const Icon(Icons.attach_file),
              onTap: () async {
                final f = await _pick(['jpg', 'jpeg', 'png', 'webp']);
                if (f != null) setState(() => _photo = f);
              },
            ),
            const Text('Tap the map to pin your station'),
            SizedBox(
              height: 240,
              child: RepaintBoundary(
                child: FlutterMap(
                  options: MapOptions(initialCenter: _pt, initialZoom: 12, onTap: (_, p) => setState(() => _pt = p)),
                  children: [
                    osmTiles(),
                    MarkerLayer(markers: [pin(_pt, Icons.store, Colors.blue)]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _submit, child: const Text('Submit application')),
          ],
        );
      },
    ),
  );
}
