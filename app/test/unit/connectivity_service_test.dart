import 'package:flutter_test/flutter_test.dart';
import 'package:omi/env/env.dart';
import 'package:omi/services/connectivity_service.dart';

class _ConnectivityEnvFields implements EnvFields {
  @override
  String? get openAIAPIKey => null;
  @override
  String? get posthogApiKey => null;
  @override
  String? get apiBaseUrl => 'https://omi.splat-i.io/';
  @override
  String? get googleMapsApiKey => null;
  @override
  String? get intercomAppId => null;
  @override
  String? get intercomIOSApiKey => null;
  @override
  String? get intercomAndroidApiKey => null;
  @override
  String? get googleClientId => null;
  @override
  String? get googleClientSecret => null;
  @override
  bool? get useWebAuth => false;
  @override
  bool? get useAuthCustomToken => false;
  @override
  String? get stagingApiUrl => 'https://omi.splat-i.io/';
}

void main() {
  setUpAll(() {
    Env.init(_ConnectivityEnvFields());
  });

  test('connectivity health probe uses configured Omi FQDN', () {
    expect(
      ConnectivityService.apiHealthCheckUri().toString(),
      'https://omi.splat-i.io/v1/health',
    );
  });
}
