/// Delivery preferences sent to the station inside the order's free-text notes,
/// one labelled line each, so stations read them without a schema change.
class DeliveryNotes {
  final String? window, handoff, instructions;
  final int emptiesToCollect;

  const DeliveryNotes({this.window, this.handoff, this.emptiesToCollect = 0, this.instructions});

  static const _window = 'Delivery window: ';
  static const _handoff = 'Handoff: ';
  static const _empties = 'Empty containers to collect: ';
  static const _instructions = 'Instructions: ';

  String encode() => [
    if (window != null && window!.isNotEmpty) '$_window$window',
    if (handoff != null && handoff!.isNotEmpty) '$_handoff$handoff',
    if (emptiesToCollect > 0) '$_empties$emptiesToCollect',
    if (instructions != null && instructions!.trim().isNotEmpty) '$_instructions${instructions!.trim()}',
  ].join('\n');

  static DeliveryNotes parse(String? notes) {
    if (notes == null || notes.trim().isEmpty) return const DeliveryNotes();
    String? window, handoff;
    var empties = 0;
    final free = <String>[];
    for (final raw in notes.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith(_window)) {
        window = line.substring(_window.length);
      } else if (line.startsWith(_handoff)) {
        handoff = line.substring(_handoff.length);
      } else if (line.startsWith(_empties)) {
        empties = int.tryParse(line.substring(_empties.length)) ?? 0;
      } else if (line.startsWith(_instructions)) {
        free.add(line.substring(_instructions.length));
      } else {
        free.add(line);
      }
    }
    return DeliveryNotes(
      window: window,
      handoff: handoff,
      emptiesToCollect: empties,
      instructions: free.isEmpty ? null : free.join('\n'),
    );
  }
}
