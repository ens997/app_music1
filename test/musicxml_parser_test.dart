import 'package:flutter_test/flutter_test.dart';
import 'package:app_music1/parsers/parsers.dart';

void main() {
  test('MusicXMLParser parses a simple score correctly', () {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work>
    <work-title>Test</work-title>
  </work>
  <identification>
    <creator type="composer">Test Composer</creator>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <key>
          <fifths>0</fifths>
        </key>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
        <clef>
          <sign>G</sign>
          <line>2</line>
        </clef>
      </attributes>
      <direction>
        <sound tempo="90"/>
      </direction>
      <note>
        <pitch>
          <step>C</step>
          <octave>4</octave>
        </pitch>
        <duration>2</duration>
        <type>quarter</type>
      </note>
      <note>
        <rest/>
        <duration>2</duration>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

    final score = MusicXMLParser.parse(xml);

    expect(score.title, 'Test');
    expect(score.composer, 'Test Composer');
    expect(score.timeSignature.numerator, 4);
    expect(score.timeSignature.denominator, 4);
    expect(score.bpm, 90);
    expect(score.divisions, 2);

    expect(score.notes.length, 2);

    final first = score.notes.first;
    expect(first.pitch, 'C4');
    expect(first.isRest, false);
    expect(first.duration, equals(first.duration));
    expect(first.absoluteTick, 0);

    final second = score.notes[1];
    expect(second.isRest, true);
    expect(second.absoluteTick, first.absoluteTick + first.durationTicks);
  });
}
