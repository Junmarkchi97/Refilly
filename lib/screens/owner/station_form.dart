import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';

class StationForm extends StatefulWidget {
  final String ownerId;
  final Station station;
  final VoidCallback onSaved;
  const StationForm({super.key, required this.ownerId, required this.station, required this.onSaved});
  @override
  State<StationForm> createState() => _StationFormState();
}

class _StationFormState extends State<StationForm> {
  late final _name = TextEditingController(text: widget.station.name);
  late final _desc = TextEditingController(text: widget.station.description);
  late final _addr = TextEditingController(text: widget.station.address);
  late final _phone = TextEditingController(text: widget.station.phone);
  late LatLng _pt = LatLng(widget.station.lat, widget.station.lng);
  late bool _open = widget.station.isOpen;
  late String? _photo = widget.station.photoUrl;
  bool _busy = false;

  Future<void> _setPhoto(String? url) async {
    await sb.from('stations').update({'photo_url': url}).eq('id', widget.station.id);
    final old = _photo;
    setState(() => _photo = url);
    if (old != null && old != url) await Api.deleteStationPhoto(old);
    widget.onSaved();
  }

  Future<void> _pickPhoto() async {
    final f = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'])).firstOrNull;
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be under 5 MB')));
      return;
    }
    var ext = f.name.split('.').last.toLowerCase();
    if (ext == 'jpeg') ext = 'jpg';
    setState(() => _busy = true);
    try {
      final url = await Api.uploadStationPhoto(widget.station.id, bytes, ext, ext == 'jpg' ? 'image/jpeg' : 'image/$ext');
      await _setPhoto(url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Station photo updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    try {
      await _setPhoto(null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final data = {
      'owner_id': widget.ownerId,
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'address': _addr.text.trim(),
      'phone': _phone.text.trim(),
      'lat': _pt.latitude,
      'lng': _pt.longitude,
      'is_open': _open,
    };
    try {
      data.remove('owner_id');
      await sb.from('stations').update(data).eq('id', widget.station.id);
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset(context, 100)),
    children: [
      Center(
        child: Stack(
          children: [
            StationAvatar(_photo, size: 112),
            if (_busy) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
      const SizedBox(height: 10),
      const Center(child: Text('Station photo', style: TextStyle(fontWeight: FontWeight.w700))),
      const Center(child: Text('Customers see this as your profile picture.', style: TextStyle(color: RF.muted, fontSize: 13))),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _pickPhoto,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(_photo == null ? 'Upload photo' : 'Replace photo'),
          ),
          if (_photo != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(onPressed: _busy ? null : _removePhoto, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Remove')),
          ],
        ],
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Station name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _desc,
        decoration: const InputDecoration(labelText: 'Description'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _addr,
        decoration: const InputDecoration(labelText: 'Address'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        decoration: const InputDecoration(labelText: 'Phone'),
      ),
      const SizedBox(height: 12),
      SwitchListTile(title: const Text('Open for orders'), value: _open, onChanged: (v) => setState(() => _open = v)),
      const Text('Tap the map to set your station location'),
      SizedBox(
        height: 260,
        child: RepaintBoundary(
          child: FlutterMap(
            options: MapOptions(initialCenter: _pt, initialZoom: 14, onTap: (_, p) => setState(() => _pt = p)),
            children: [
              osmTiles(),
              MarkerLayer(markers: [photoPin(_pt, _photo)]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _save, child: const Text('Save station')),
    ],
  );
}
