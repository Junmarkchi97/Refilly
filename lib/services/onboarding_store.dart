import 'package:shared_preferences/shared_preferences.dart';

/// Persisted on the device/browser, not in Supabase. Returning customers
/// are not interrupted by the welcome carousel each time they open Refilly.
class OnboardingStore {
  static const completedKey = 'refilly_onboarding_v1_completed';

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completedKey) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(completedKey, true)) {
      throw StateError('Could not save onboarding progress');
    }
  }
}
