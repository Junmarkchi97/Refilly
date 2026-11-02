import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../network_states.dart';
import '../widgets.dart';

/// Round profile photo, or the first letter of the name when none is set.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.radius = 28,
    this.background = RF.ink,
    this.foreground = Colors.white,
  });

  final Profile profile;
  final double radius;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        _initial(profile),
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: radius * .78),
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : SizedBox(width: radius * 2, height: radius * 2, child: fallback),
      ),
    );
  }
}

/// Account avatar that can choose or remove a profile photo.
class EditableProfilePhoto extends StatefulWidget {
  const EditableProfilePhoto({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ValueChanged<Profile> onChanged;

  @override
  State<EditableProfilePhoto> createState() => _EditableProfilePhotoState();
}

class _EditableProfilePhotoState extends State<EditableProfilePhoto> {
  bool _busy = false;

  Future<void> _choose() async {
    if (_busy) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose photo'),
              onTap: () => Navigator.pop(sheetContext, 'pick'),
            ),
            if (widget.profile.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      final ok = await confirmRemove(
        context,
        title: 'Remove profile photo?',
        message: 'Your account will show your initial until you add a new photo.',
      );
      if (!ok || !mounted) return;
      await _run(Api.removeProfilePhoto, success: 'Profile photo removed');
      return;
    }
    final file = (await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    )).firstOrNull;
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      showAppNotice(context, 'Image must be under 5 MB');
      return;
    }
    var ext = (file.extension ?? file.name.split('.').last).toLowerCase();
    if (ext == 'jpeg') ext = 'jpg';
    if (!const {'jpg', 'png', 'webp'}.contains(ext)) {
      showAppNotice(context, 'Use a JPG, PNG, or WebP photo.');
      return;
    }
    final type = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    await _run(
      () => Api.saveProfilePhoto(bytes, ext, type),
      success: 'Profile photo updated',
      failed: 'Could not update your profile photo.',
    );
  }

  Future<void> _run(
    Future<Profile> Function() action, {
    required String success,
    String failed = 'Could not update your profile photo.',
  }) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      widget.onChanged(updated);
      showAppNotice(context, success, kind: AppNotice.success);
    } catch (e) {
      if (mounted) showFailureNotice(context, e, failed: failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Change profile photo',
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: _busy ? null : _choose,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(profile: widget.profile, radius: 28),
            if (_busy)
              const Positioned.fill(
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
              ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: RF.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _initial(Profile profile) {
  final name = (profile.fullName ?? '').trim();
  if (name.isEmpty) return '?';
  return name.characters.first.toUpperCase();
}
