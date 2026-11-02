import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/delivery_notes.dart';

void main() {
  test('delivery preferences round-trip through order notes', () {
    const notes = DeliveryNotes(
      window: 'Today, 2 PM–4 PM',
      handoff: 'Lobby',
      emptiesToCollect: 2,
      instructions: 'Call when you arrive.',
    );
    final parsed = DeliveryNotes.parse(notes.encode());
    expect(parsed.window, 'Today, 2 PM–4 PM');
    expect(parsed.handoff, 'Lobby');
    expect(parsed.emptiesToCollect, 2);
    expect(parsed.instructions, 'Call when you arrive.');
  });

  test('older free-text notes are kept as instructions', () {
    final parsed = DeliveryNotes.parse('Gate code 1234');
    expect(parsed.window, isNull);
    expect(parsed.emptiesToCollect, 0);
    expect(parsed.instructions, 'Gate code 1234');
  });

  test('empty preferences encode to an empty string', () {
    expect(const DeliveryNotes().encode(), isEmpty);
    expect(DeliveryNotes.parse(null).instructions, isNull);
  });
}
