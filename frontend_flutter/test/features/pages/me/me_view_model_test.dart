import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MeViewModel can load and update response style preference', () async {
    SharedPreferences.setMockInitialValues({
      'repeat_area_preference': 'emotion_stress',
      'response_style_preference': 'gentle',
    });

    final vm = MeViewModel();
    await vm.load();

    expect(vm.selectedResponseStyle, 'gentle');

    final ok = await vm.updateResponseStyle('direct');
    expect(ok, true);
    expect(vm.selectedResponseStyle, 'direct');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('response_style_preference'), 'direct');
  });
}
