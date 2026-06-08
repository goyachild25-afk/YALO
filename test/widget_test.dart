import 'package:flutter_test/flutter_test.dart';
import 'package:servicios_ya/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(ServiciosYaApp, isNotNull);
  });
}
