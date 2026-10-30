import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../admin/admin_home.dart';
import '../auth/verify_phone_screen.dart';
import '../owner/owner_home.dart';
import 'apply_owner_screen.dart';

/// Glide-style side sheet that slides in from the left over the map.
Future<void> showAppDrawer(BuildContext context, Profile profile, {required VoidCallback onOrders, required VoidCallback onAccount}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close menu',
    barrierColor: Colors.black.withValues(alpha: .32),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, _) => _AppDrawer(profile: profile, onOrders: onOrders, onAccount: onAccount),
    transitionBuilder: (ctx, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(-1, 0), end: Offset.zero).animate(c),
        child: child,
      );
    },
  );
}

class _AppDrawer extends StatelessWidget {
  final Profile profile;
  final VoidCallback onOrders, onAccount;
  const _AppDrawer({required this.profile, required this.onOrders, required this.onAccount});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final verified = Api.phoneVerified;
    final phone = sb.auth.currentUser?.phone?.isNotEmpty == true ? '+${sb.auth.currentUser!.phone}' : profile.phone;
    void close() => Navigator.of(context).pop();
    void push(Widget page) {
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(MaterialPageRoute(builder: (_) => page));
    }

    final roleItem = switch (profile.role) {
      'owner' => (Icons.storefront_rounded, 'Owner dashboard', () => push(OwnerHome(profile: profile))),
      'admin' => (Icons.admin_panel_settings_rounded, 'Admin', () => push(AdminHome(profile: profile))),
      _ => (Icons.storefront_rounded, 'Become a station owner', () => push(const ApplyOwnerScreen())),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(RF.sheetRadius)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: w < 420 ? w * .84 : 340,
          height: double.infinity,
          child: SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: RF.ink,
                        child: Text(
                          (profile.fullName ?? '?').characters.first.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName ?? 'Customer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    phone?.isNotEmpty == true ? phone! : 'No phone yet',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: RF.muted, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: verified ? const Color(0xFFE6F6EC) : RF.fill,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        verified ? Icons.verified_rounded : Icons.error_outline_rounded,
                                        size: 12,
                                        color: verified ? const Color(0xFF1E9E55) : RF.muted,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        verified ? 'Verified' : 'Unverified',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: verified ? const Color(0xFF1E9E55) : RF.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: close, icon: const Icon(Icons.close_rounded), tooltip: 'Close'),
                    ],
                  ),
                ),
                const Divider(height: 1, color: RF.line),
                const SizedBox(height: 8),
                _Item(Icons.receipt_long_rounded, 'Orders', () {
                  close();
                  onOrders();
                }),
                _Item(Icons.person_rounded, 'Account', () {
                  close();
                  onAccount();
                }),
                _Item(
                  Icons.verified_user_rounded,
                  'Verify phone',
                  () => push(VerifyPhoneScreen(initialPhone: profile.phone)),
                  trailing: verified ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E9E55), size: 20) : null,
                ),
                _Item(roleItem.$1, roleItem.$2, roleItem.$3),
                _Item(Icons.help_outline_rounded, 'Help', () {
                  close();
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Help'),
                      content: const Text(
                        'Pick a station on the map, add items, and check out. You can track your rider live from Orders.\n\n'
                        'Questions about an order? Call the station from the order screen.',
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
                    ),
                  );
                }),
                const Spacer(),
                const Divider(height: 1, color: RF.line),
                _Item(Icons.logout_rounded, 'Log out', () {
                  close();
                  sb.auth.signOut();
                }, color: Colors.redAccent),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? color;
  const _Item(this.icon, this.label, this.onTap, {this.trailing, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: RF.fill, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: color ?? RF.ink),
      ),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: color ?? RF.ink),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: RF.muted),
      onTap: onTap,
    ),
  );
}
