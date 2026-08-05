import 'dart:io';
import 'dart:typed_data';

/// `Flutter3DViewer` loads models the same way `<model-viewer>` does on
/// the web: from an asset declared at build time, or from a URL. There is
/// no "load these bytes I just generated" API — which is exactly what a
/// chart needs, since its `.glb` is built fresh from live data.
///
/// The fix used throughout the flutter_3d_controller/model-viewer
/// ecosystem for dynamically-generated models is to serve the bytes over
/// a tiny loopback HTTP server and pass `http://127.0.0.1:port/...` as
/// `src`. This class does exactly that for a single file at a time.
///
/// Note: on Android this requires `usesCleartextTraffic="true"` in
/// `AndroidManifest.xml` (see the flutter_3d_controller install docs) —
/// same requirement as loading any other non-HTTPS local URL.
class LocalModelServer {
  HttpServer? _server;
  Uint8List? _bytes;
  String _token = '';

  bool get isRunning => _server != null;

  /// Starts the server (if not already running) and publishes [bytes] as
  /// the current model. Returns the URL to hand to `Flutter3DViewer.src`.
  Future<String> serve(Uint8List bytes) async {
    // `_bytes`/`_token` are read inside the request handler closure below,
    // so updating them here is enough to change what's served — the
    // server itself (and its single-subscription `listen`) is only ever
    // set up once, on the first call.
    _bytes = bytes;
    _token = DateTime.now().microsecondsSinceEpoch.toString();

    if (_server == null) {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen((request) async {
        if (request.method == 'OPTIONS') {
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          request.response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
          request.response.headers.set('Access-Control-Allow-Headers', '*');
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        if (request.uri.path.endsWith('.glb') && _bytes != null) {
          request.response.headers.contentType = ContentType(
            'model',
            'gltf-binary',
          );
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          request.response.contentLength = _bytes!.length;
          request.response.add(_bytes!);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
    }

    return 'http://127.0.0.1:${_server!.port}/$_token.glb';
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
  }
}
