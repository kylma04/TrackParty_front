abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8000/ws',
  );
  static const googleWebClientId  = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleMapsApiKey   = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  // Serveur TURN pour les appels WebRTC. Indispensable sur réseaux mobiles à NAT
  // strict (sinon les appels se connectent puis coupent). Format URL :
  // 'turn:host:3478' ou 'turns:host:5349'. Laisser vide = STUN seul (P2P direct only).
  static const turnUrl        = String.fromEnvironment('TURN_URL');
  static const turnUsername   = String.fromEnvironment('TURN_USERNAME');
  static const turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

  static bool get turnConfigured => turnUrl.isNotEmpty;

  static const cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dsc2w5ivp',
  );
  static const cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'trackparty_upload',
  );

  static bool get googleConfigured => googleWebClientId.isNotEmpty;
  static bool get cloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;
}
