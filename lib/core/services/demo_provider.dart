import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/models/user_model.dart';
import 'demo_data.dart';

// Estado global del modo demo
final demoModeProvider = StateProvider<bool>((ref) => false);
final demoUserProvider = StateProvider<UserModel?>((ref) => null);

// Activa el modo demo como cliente
void enterDemoAsClient(WidgetRef ref) {
  ref.read(demoModeProvider.notifier).state = true;
  ref.read(demoUserProvider.notifier).state = DemoData.clientUser;
}

// Activa el modo demo como prestador
void enterDemoAsProvider(WidgetRef ref) {
  ref.read(demoModeProvider.notifier).state = true;
  ref.read(demoUserProvider.notifier).state = DemoData.providerUser;
}

// Cierra el modo demo
void exitDemo(WidgetRef ref) {
  ref.read(demoModeProvider.notifier).state = false;
  ref.read(demoUserProvider.notifier).state = null;
}
