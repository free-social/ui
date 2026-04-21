import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

/// Rewrites a Cloudinary URL to go through the authenticated API proxy.
///
/// Example:
///   Input:  https://res.cloudinary.com/dzzv7uxg8/image/upload/v123/chat/image/abc.jpg
///   Output: https://walletvps.duckdns.org/api/v1/media/image/upload/v123/chat/image/abc.jpg
String toProxyUrl(String cloudinaryUrl) {
  if (cloudinaryUrl.isEmpty) return cloudinaryUrl;

  const cloudinaryPrefix = 'res.cloudinary.com/';
  final idx = cloudinaryUrl.indexOf(cloudinaryPrefix);
  if (idx == -1) return cloudinaryUrl;

  // Extract everything after the cloud name
  final afterPrefix = cloudinaryUrl.substring(idx + cloudinaryPrefix.length);
  final slashIdx = afterPrefix.indexOf('/');
  if (slashIdx == -1) return cloudinaryUrl;

  // path = "image/upload/v123/chat/image/abc.jpg"
  final path = afterPrefix.substring(slashIdx + 1);
  return '${ApiConstants.baseUrl}/media/$path';
}

/// Returns auth headers map synchronously from the cached token.
/// Must call [initAuthImageHeaders] at least once before using.
Map<String, String> get authImageHeaders {
  final t = _cachedToken;
  if (t == null || t.isEmpty) return const {};
  return {'Authorization': 'Bearer $t'};
}

String? _cachedToken;

/// Initialise / refresh the cached token. Call this once on app startup
/// or whenever the token changes (login/logout).
Future<void> initAuthImageHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  _cachedToken = prefs.getString('token');
}

/// Updates the cached token immediately (call after login/logout).
void setAuthImageToken(String? token) {
  _cachedToken = token;
}

/// A convenience [CachedNetworkImageProvider] that rewrites the URL
/// to the authenticated proxy and attaches the auth header.
CachedNetworkImageProvider authImageProvider(String url, {
  double scale = 1.0,
  Map<String, String>? extraHeaders,
}) {
  return CachedNetworkImageProvider(
    toProxyUrl(url),
    scale: scale,
    headers: {...authImageHeaders, ...?extraHeaders},
  );
}
