import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/research_overview.dart';

void main() {
  test('Participant codes sort by number, P10 last, uncoded after', () {
    final codes = <String?>['P10', null, 'P2', 'P1', 'P9', null, 'P3']
      ..sort(compareParticipantCodes);
    expect(codes, ['P1', 'P2', 'P3', 'P9', 'P10', null, null]);
  });
}
