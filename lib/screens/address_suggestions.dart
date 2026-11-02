import 'package:flutter/material.dart';

import '../services/address_search.dart';
import '../theme.dart';

/// Address matches floating over the field. The menu scrolls on its own and
/// does not push the page content down.
class AddressSuggestAnchor extends StatefulWidget {
  final bool open;
  final bool searching;
  final String? error;
  final List<AddressSuggestion> suggestions;
  final ValueChanged<AddressSuggestion> onSelected;
  final Widget child;
  const AddressSuggestAnchor({
    super.key,
    required this.open,
    required this.searching,
    required this.suggestions,
    required this.onSelected,
    required this.child,
    this.error,
  });

  @override
  State<AddressSuggestAnchor> createState() => _AddressSuggestAnchorState();
}

class _AddressSuggestAnchorState extends State<AddressSuggestAnchor> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        if (!widget.open) return const SizedBox.shrink();
        return CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: _AddressMenu(
                searching: widget.searching,
                error: widget.error,
                suggestions: widget.suggestions,
                onSelected: widget.onSelected,
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(link: _link, child: widget.child),
    ),
  );
}

class _AddressMenu extends StatelessWidget {
  final bool searching;
  final String? error;
  final List<AddressSuggestion> suggestions;
  final ValueChanged<AddressSuggestion> onSelected;
  const _AddressMenu({
    required this.searching,
    required this.error,
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (searching) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(child: Text('Searching Philippine addresses…')),
        ]),
      );
    } else if (error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error!, style: const TextStyle(color: RF.muted, fontSize: 13)),
      );
    } else if (suggestions.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No matches yet. Try a house number, landmark, or pin the map.',
          style: TextStyle(color: RF.muted, fontSize: 13),
        ),
      );
    } else {
      body = ListView.builder(
        shrinkWrap: true,
        primary: false,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final result = suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined, color: RF.muted),
            title: Text(result.label, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => onSelected(result),
          );
        },
      );
    }

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E2DC)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(constraints: const BoxConstraints(maxHeight: 280), child: body),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Address suggestions · OpenStreetMap / Photon',
                style: TextStyle(color: RF.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
