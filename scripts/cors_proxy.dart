// Lightweight reverse proxy that adds CORS + Private-Network-Access headers
// in front of go2rtc (which has no CORS support), so Flutter Web / Chrome
// can fetch camera snapshots/streams from it.
//
// Run with: dart run scripts/cors_proxy.dart
// Then point the app at http://<this-machine-ip>:8090/... instead of :1984/...
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _targetHost = 'localhost';
const _targetPort = 1984;
const _listenPort = 8090;
final _snapshotDirectory = Directory('${Directory.current.path}${Platform.pathSeparator}snapshots');

void _addCorsHeaders(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', '*');
  response.headers.set('Access-Control-Allow-Private-Network', 'true');
  response.headers.set('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
  response.headers.set('Pragma', 'no-cache');
}

Future<void> _handleWebSocket(HttpRequest request) async {
  final clientSocket = await WebSocketTransformer.upgrade(request);
  final upstreamUri = Uri.parse('ws://$_targetHost:$_targetPort${request.uri}');

  try {
    final upstreamSocket = await WebSocket.connect(upstreamUri.toString());
    clientSocket.listen(
      upstreamSocket.add,
      onDone: upstreamSocket.close,
    );
    upstreamSocket.listen(
      clientSocket.add,
      onDone: clientSocket.close,
    );
  } catch (_) {
    await clientSocket.close();
  }
}

Future<void> _handleSnapshot(HttpRequest request) async {
  final relativePath = request.uri.path.substring('/snapshots/'.length);
  if (relativePath.isEmpty || relativePath.contains('..') || !relativePath.endsWith('.jpg')) {
    request.response.statusCode = HttpStatus.badRequest;
    await request.response.close();
    return;
  }

  final file = File('${_snapshotDirectory.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}');
  if (!await file.exists()) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  _addCorsHeaders(request.response);
  request.response.headers.contentType = ContentType('image', 'jpeg');
  await file.openRead().pipe(request.response);
}

Future<void> _handleHealth(HttpClient client, HttpRequest request) async {
  final streamName = request.uri.queryParameters['src'];
  if (streamName == null || streamName.isEmpty) {
    request.response.statusCode = HttpStatus.badRequest;
    await request.response.close();
    return;
  }

  try {
    final upstream = await client.get(_targetHost, _targetPort, '/api/streams');
    final upstreamResponse = await upstream.close();
    final responseBody = await utf8.decodeStream(upstreamResponse);
    final streams = jsonDecode(responseBody) as Map<String, dynamic>;
    final stream = streams[streamName] as Map<String, dynamic>?;
    final producers = stream?['producers'] as List<dynamic>? ?? const [];

    request.response.statusCode = producers.isNotEmpty ? HttpStatus.ok : HttpStatus.serviceUnavailable;
    _addCorsHeaders(request.response);
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'online': producers.isNotEmpty}));
    await request.response.close();
  } catch (_) {
    request.response.statusCode = HttpStatus.serviceUnavailable;
    _addCorsHeaders(request.response);
    await request.response.close();
  }
}

Future<void> _handleRequest(HttpClient client, HttpRequest request) async {
  if (request.uri.path == '/api/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
    await _handleWebSocket(request);
    return;
  }

  _addCorsHeaders(request.response);

  if (request.method == 'OPTIONS') {
    request.response.statusCode = 204;
    await request.response.close();
    return;
  }

  if (request.uri.path.startsWith('/snapshots/')) {
    await _handleSnapshot(request);
    return;
  }

  if (request.uri.path == '/health') {
    await _handleHealth(client, request);
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
