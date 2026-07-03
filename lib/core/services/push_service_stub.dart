// Stub para plataformas sin dart:html (VM de tests, móvil nativo futuro).
// El push con la app cerrada solo aplica a web; aquí simplemente no hay
// suscripción y PushService.ensureSubscribed() termina sin efecto.
Future<Map<String, String>?> subscribeToWebPush(String vapidPublicKey) async =>
    null;
