import 'package:flutter_test/flutter_test.dart';
import 'package:ai_tutor/main.dart';

void main() {
  testWidgets('Home screen shows the title and upload button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SlideTutorApp());

    expect(find.text('Slide Tutor'), findsOneWidget);
    expect(find.text('Upload your slides (PDF)'), findsOneWidget);
  });
}
