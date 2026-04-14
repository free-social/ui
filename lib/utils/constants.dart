// File: lib/utils/constants.dart

class ApiConstants {
  // 1. PHYSICAL DEVICE (Your current Wi-Fi IP)
  // Use this when running on your real phone
  // static const String baseUrl = 'http://localhost:4001/api/v1';

  // 2. Production
  // static const String baseUrl = 'https://expenses-api-j638.onrender.com/api/v1';
  static const String baseUrl = 'https://walletvps.duckdns.org/api/v1';

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '', query: null, fragment: null).toString();
  }

  static List<Map<String, dynamic>> get rtcIceServers {
    final servers = <Map<String, dynamic>>[
      <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      <String, dynamic>{'urls': 'stun:stun1.l.google.com:19302'},
    ];

    const turnUrlsValue = String.fromEnvironment('RTC_TURN_URLS');
    const turnUsername = String.fromEnvironment('RTC_TURN_USERNAME');
    const turnCredential = String.fromEnvironment('RTC_TURN_CREDENTIAL');

    final turnUrls = turnUrlsValue
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (turnUrls.isNotEmpty) {
      servers.add(<String, dynamic>{
        'urls': turnUrls,
        if (turnUsername.trim().isNotEmpty) 'username': turnUsername.trim(),
        if (turnCredential.trim().isNotEmpty)
          'credential': turnCredential.trim(),
      });
    }

    return servers;
  }
}
