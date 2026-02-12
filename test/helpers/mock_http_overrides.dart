import 'dart:io';
import 'dart:async';
import 'dart:convert';

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  set userAgent(String? userAgent) {}

  @override
  set idleTimeout(Duration timeout) {}

  @override
  set connectionTimeout(Duration? timeout) {}

  @override
  set maxConnectionsPerHost(int? maxConnectionsPerHost) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (url.toString().endsWith('.png') || url.toString().contains('google')) {
      return MockHttpClientRequest(isImage: true);
    }
    return MockHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async => MockHttpClientRequest();

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async => MockHttpClientRequest();

  @override
  Future<HttpClientRequest> putUrl(Uri url) async => MockHttpClientRequest();

  @override
  Future<HttpClientRequest> headUrl(Uri url) async => MockHttpClientRequest();

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async => MockHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      MockHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class MockHttpClientRequest implements HttpClientRequest {
  final bool isImage;

  MockHttpClientRequest({this.isImage = false});

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}

  @override
  void writeAll(Iterable objects, [String separator = ""]) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeLn([Object? obj = ""]) {}

  @override
  Encoding get encoding => const Utf8Codec();

  @override
  set encoding(Encoding value) {}

  @override
  Future<HttpClientResponse> close() async =>
      MockHttpClientResponse(isImage: isImage);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class MockHttpClientResponse implements HttpClientResponse {
  final bool isImage;

  MockHttpClientResponse({this.isImage = false});

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => "OK";

  @override
  int get contentLength => isImage ? _transparentImage.length : 2;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final data = isImage ? _transparentImage : utf8.encode('{}');
    return Stream<List<int>>.fromIterable([data]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// 1x1 Transparent PNG
const List<int> _transparentImage = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
