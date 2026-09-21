import 'package:http/http.dart' as http;

/// Non-committal HTTP response surface the update layer needs.
final class UpdateHttpResponse {
  /// Creates the response shell.
  const UpdateHttpResponse({
    required this.status,
    required this.body,
    this.contentLength,
  });

  /// HTTP status code.
  final int status;

  /// Single-subscription body stream.
  final Stream<List<int>> body;

  /// Total body size in bytes when advertised (`Content-Length`).
  final int? contentLength;
}

/// HTTP seam (tests inject fakes — no network in unit tests,
/// docs/03 § 10.2.9). Single-method by design: it is the fake
/// boundary and grows with the update protocol.
// ignore: one_member_abstracts, see doc above
abstract interface class UpdateHttpClient {
  /// Fetches [url], optionally with extra [headers].
  Future<UpdateHttpResponse> fetch(Uri url, {Map<String, String>? headers});
}

/// Production [UpdateHttpClient] over the `http` package.
final class HttpUpdateHttpClient implements UpdateHttpClient {
  /// Creates the client over an injectable inner [client].
  HttpUpdateHttpClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Closes the inner client.
  void close() => _client.close();

  @override
  Future<UpdateHttpResponse> fetch(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final request = http.Request('GET', url)..followRedirects = true;
    if (headers != null) {
      request.headers.addAll(headers);
    }
    final response = await _client.send(request);
    return UpdateHttpResponse(
      status: response.statusCode,
      body: response.stream,
      contentLength: response.contentLength,
    );
  }
}
