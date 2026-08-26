// Lightweight reverse proxy that adds CORS + Private-Network-Access headers
// in front of go2rtc (which has no CORS support), so Flutter Web / Chrome
// can fetch camera snapshots/streams from it.
//
// Run with: dart run scripts/cors_proxy.dart
// Then point the app at http://<this-machine-ip>:8090/... instead of :1984/...
import 'dart:async';
import 'dart:io';

const _targetHost = 'localhost';
const _targetPort = 1984;
const _listenPort = 8090;

void _addCorsHeaders(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', '*');
  response.headers.set('Access-Control-Allow-Private-Network', 'true');
}

Future<void> _handleRequest(HttpClient client, HttpRequest request) async {
  _addCorsHeaders(request.response);

  if (request.method == 'OPTIONS') {
    request.response.statusCode = 204;
    await request.response.close();
    return;
  }

  try {
    final upstream = await client.open(
      request.method,
      _targetHost,
      _targetPort,
      request.uri.toString(),
    );
    final upstreamResponse = await upstream.close();
    request.response.statusCode = upstreamResponse.statusCode;
    upstreamResponse.headers.forEach((name, values) {
      if (name.toLowerCase() == 'content-length' ||
          name.toLowerCase() == 'transfer-encoding') {
        return;
      }
      for (final value in values) {
        request.response.headers.add(name, value);
      }
    });
    _addCorsHeaders(request.response);
    await upstreamResponse.pipe(request.response);
  } catch (e) {
    try {
      request.response.statusCode = 502;
      request.response.write('Proxy error: $e');
      await request.response.close();
    } catch (_) {
      // response may already be closed/broken; nothing more we can do
    }
  }
}

Future<void> main() async {
  // Use a fresh HttpClient per request handler set so one slow/broken camera
  // connection can't stall connection reuse for the other camera's requests.
  final server = await HttpServer.bind(InternetAddress.anyIPv4, _listenPort);
  stdout.writeln('CORS proxy listening on http://0.0.0.0:$_listenPort -> http://$_targetHost:$_targetPort');

  final client = HttpClient()..maxConnectionsPerHost = 20;

  // Handle each request concurrently instead of awaiting it in the accept
  // loop, so two camera feeds polling in parallel don't queue behind each other.
  await for (final request in server) {
    unawaited(_handleRequest(client, request));
  }
}
