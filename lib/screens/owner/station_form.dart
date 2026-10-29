import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';

class StationForm extends StatefulWidget {
  final String ownerId;
  final Station? station;
  final VoidCallback onSaved;
  const StationForm({super.key, required this.ownerId, this.station, required this.onSaved});
  @override
  State<StationForm> createState() => _StationFormState();
}

class _StationFormState extends State<StationForm> {
  late final _name = TextEditingController(text: widget.station?.name);
  late final _desc = TextEditingController(text: widget.station?.description);
  late final _addr = TextEditingController(text: widget.station?.address);
  late final _phone = TextEditingController(text: widget.station?.phone);
  late LatLng _pt = widget.station == null ? manila : LatLng(widget.station!.lat, widget.station!.lng);
  late bool _open = widget.station?.isOpen ?? true;

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
      if (widget.station == null) {
        await sb.from('stations').insert(data);
      } else {
        await sb.from('stations').update(data).eq('id', widget.station!.id);
      }
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Station name')),
        TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
        TextField(controller: _addr, decoration: const InputDecoration(labelText: 'Address')),
        TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
        SwitchListTile(title: const Text('Open for orders'), value: _open, onChanged: (v) => setState(() => _open = v)),
        const Text('Tap the map to set your station location'),
        SizedBox(
          height: 260,
          child: FlutterMap(
            options: MapOptions(initialCenter: _pt, initialZoom: 14, onTap: (_, p) => setState(() => _pt = p)),
            children: [osmTiles(), MarkerLayer(markers: [pin(_pt, Icons.store, Colors.blue)])],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('Save station')),
      ]);
}
