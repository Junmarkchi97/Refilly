import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/location.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Customers apply to become station owners; an admin reviews the documents.
class ApplyOwnerScreen extends StatefulWidget {
  const ApplyOwnerScreen({super.key});
  @override
  State<ApplyOwnerScreen> createState() => _ApplyOwnerScreenState();
}

class _Doc {
  final String name;
  final Uint8List bytes;
  _Doc(this.name, this.bytes);
  bool get isImage => RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(name);
}

class _ApplyOwnerScreenState extends State<ApplyOwnerScreen> {
  late Future<List<OwnerApplication>> _mine = Api.myApplications();
  final _biz = TextEditingController(),
      _station = TextEditingController(),
      _addr = TextEditingController(),
      _phone = TextEditingController();
  final _map = MapController();
  LatLng _pt = manila;
  bool _pinned = false, _busy = false, _sent = false;
  _Doc? _permit, _photo;

  bool get _valid =>
      _biz.text.trim().isNotEmpty &&
      _station.text.trim().isNotEmpty &&
      _addr.text.trim().isNotEmpty &&
      _phone.text.replaceAll(RegExp(r'\D'), '').length >= 10 &&
      _permit != null &&
      _photo != null &&
      _pinned;

  Future<_Doc?> _pick(List<String> ext) async {
    final f = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ext)).firstOrNull;
    if (f == null) return null;
    return _Doc(f.name, await f.readAsBytes());
  }

  String _mime(String n) => switch (n.split('.').last.toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  Future<void> _locate() async {
    final p = await LocationService.current();
    if (p == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allow location access, or drag the map instead')));
      }
      return;
    }
    setState(() {
      _pt = LatLng(p.latitude, p.longitude);
      _pinned = true;
    });
    _map.move(_pt, 17);
  }

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() => _busy = true);
    try {
      final permit = await Api.uploadDoc('permit_${_permit!.name}', _permit!.bytes, _mime(_permit!.name));
      final photo = await Api.uploadDoc('photo_${_photo!.name}', _photo!.bytes, _mime(_photo!.name));
      await Api.submitApplication({
        'business_name': _biz.text.trim(),
        'station_name': _station.text.trim(),
        'address': _addr.text.trim(),
        'phone': Api.toE164(_phone.text),
        'lat': _pt.latitude,
        'lng': _pt.longitude,
        'permit_path': permit,
        'photo_path': photo,
      });
      setState(() {
        _sent = true;
        _mine = Api.myApplications();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.mark_email_read_rounded,
          title: 'Application sent',
          subtitle: "We'll review your documents within 24 hours. You'll become an owner once approved — log out and in again to see your dashboard.",
        ),
        bottomNavigationBar: BottomActionBar(
          child: PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
        ),
      );
    }
    return FutureBuilder<List<OwnerApplication>>(
      future: _mine,
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: SkeletonList());
        final last = snap.data!.firstOrNull;
        if (last != null && last.status != 'rejected') return _statusScreen(last);
        return Scaffold(
          appBar: AppBar(),
          bottomNavigationBar: BottomActionBar(
            child: PrimaryButton(label: 'Submit application', busy: _busy, onPressed: _valid ? _submit : null),
          ),
          body: ListView(
            padding: EdgeInsets.only(bottom: bottomInset(context)),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Become a station owner', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    const Text(
                      'Sell water and daily essentials on Refilly. We verify every station before it goes live.',
                      style: TextStyle(color: RF.muted),
                    ),
                  ],
                ),
              ),
              if (last?.status == 'rejected') Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _statusCard(last!)),
              FormSection(
                title: 'Business details',
                children: [
                  LabeledField(
                    controller: _biz,
                    label: 'Registered business name',
                    icon: Icons.business_rounded,
                    hint: 'e.g. Juan Water Trading',
                    onChanged: (_) => setState(() {}),
                  ),
                  LabeledField(
                    controller: _station,
                    label: 'Station name',
                    icon: Icons.storefront_rounded,
                    hint: 'Shown to customers',
                    onChanged: (_) => setState(() {}),
                  ),
                  LabeledField(
                    controller: _addr,
                    label: 'Station address',
                    icon: Icons.place_rounded,
                    hint: 'House no., street, barangay, city',
                    onChanged: (_) => setState(() {}),
                  ),
                  LabeledField(
                    controller: _phone,
                    label: 'Station mobile',
                    icon: Icons.phone_iphone_rounded,
                    prefixText: '+63 ',
                    hint: '917 123 4567',
                    keyboard: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              FormSection(
                title: 'Documents',
                subtitle: 'Images or PDF, up to 10 MB. Only admins can see these.',
                children: [
                  UploadCard(
                    icon: Icons.badge_rounded,
                    title: 'DTI / SEC or business permit',
                    hint: 'Tap to upload',
                    fileName: _permit?.name,
                    thumb: (_permit?.isImage ?? false) ? _permit!.bytes : null,
                    onPick: () async {
                      final d = await _pick(['pdf', 'jpg', 'jpeg', 'png', 'webp']);
                      if (d != null) setState(() => _permit = d);
                    },
                    onRemove: () => setState(() => _permit = null),
                  ),
                  UploadCard(
                    icon: Icons.add_a_photo_rounded,
                    title: 'Photo of your station',
                    hint: 'Storefront with signage',
                    fileName: _photo?.name,
                    thumb: _photo?.bytes,
                    onPick: () async {
                      final d = await _pick(['jpg', 'jpeg', 'png', 'webp']);
                      if (d != null) setState(() => _photo = d);
                    },
                    onRemove: () => setState(() => _photo = null),
                  ),
                ],
              ),
              FormSection(
                title: 'Station location',
                subtitle: 'Drag the map so the pin sits on your station.',
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RF.radius),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RepaintBoundary(
                            child: FlutterMap(
                              mapController: _map,
                              options: MapOptions(
                                initialCenter: _pt,
                                initialZoom: 13,
                                onPositionChanged: (cam, gesture) {
                                  if (gesture) {
                                    setState(() {
                                      _pt = cam.center;
                                      _pinned = true;
                                    });
                                  }
                                },
                              ),
                              children: [osmTiles(), osmAttribution()],
                            ),
                          ),
                          const IgnorePointer(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 34),
                              child: Icon(Icons.location_on_rounded, size: 40, color: RF.ink),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: MapButton(Icons.my_location_rounded, label: 'Use my location', onTap: _locate),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InfoBox(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          _pinned ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 20,
                          color: _pinned ? const Color(0xFF1DB954) : RF.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pinned ? (_addr.text.trim().isEmpty ? 'Pinned location' : _addr.text.trim()) : 'Location not set yet',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_pt.latitude.toStringAsFixed(5)}, ${_pt.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(color: RF.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!_valid)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Fill in all details, add both documents and pin your location to submit.',
                    style: TextStyle(color: RF.muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(OwnerApplication a) {
    final (icon, color, title, sub) = switch (a.status) {
      'approved' => (Icons.verified_rounded, const Color(0xFF1DB954), 'Approved', 'Log out and in again to open your owner dashboard.'),
      'rejected' => (
        Icons.cancel_rounded,
        Colors.redAccent,
        'Not approved',
        a.notes?.isNotEmpty == true ? a.notes! : 'Please check your documents and apply again.',
      ),
      _ => (Icons.hourglass_top_rounded, const Color(0xFFE8890C), 'Under review', "We'll review your application within 24 hours."),
    };
    return InfoBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(a.stationName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: RF.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusScreen(OwnerApplication a) => Scaffold(
    appBar: AppBar(),
    body: ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset(context)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('Your application', style: Theme.of(context).textTheme.headlineMedium),
        ),
        _statusCard(a),
        const SizedBox(height: 12),
        InfoBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CapsLabel('Submitted'),
              const SizedBox(height: 4),
              Text(a.businessName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(a.address, style: const TextStyle(color: RF.muted)),
              Text(MaterialLocalizations.of(context).formatMediumDate(a.createdAt), style: const TextStyle(color: RF.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: BottomActionBar(
      child: PrimaryButton(label: 'Back to Refilly', onPressed: () => Navigator.pop(context)),
    ),
  );
}
