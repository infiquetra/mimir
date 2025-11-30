import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A temporary HTTP server that receives OAuth callbacks and displays
/// a success page in the browser.
///
/// This solves the UX issue where the browser is left hanging with a loading
/// spinner after OAuth authorization. The browser now receives a nice success
/// page while the app processes the callback.
class OAuthCallbackServer {
  HttpServer? _server;
  final Completer<Uri> _callbackCompleter = Completer<Uri>();

  /// The callback URL for this server instance.
  String get callbackUrl => 'http://127.0.0.1:${_server?.port}/callback';

  /// Future that completes when a callback is received.
  Future<Uri> get onCallback => _callbackCompleter.future;

  /// Starts the server on a random available port.
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    debugPrint('[OAUTH_SERVER] Listening on $callbackUrl');

    _server!.listen(_handleRequest);
  }

  void _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/callback') {
      // Send success page to browser
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_successHtml)
        ..close();

      // Complete the callback future
      if (!_callbackCompleter.isCompleted) {
        _callbackCompleter.complete(request.uri);
      }

      // Stop server after a short delay
      Future.delayed(const Duration(seconds: 1), stop);
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    }
  }

  /// Stops the server.
  Future<void> stop() async {
    await _server?.close();
    _server = null;
    debugPrint('[OAUTH_SERVER] Server stopped');
  }

  static const _successHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Authorization Successful - Mimir</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #0a0a0f;
      background-image:
        radial-gradient(ellipse at 50% 0%, rgba(30, 60, 90, 0.3) 0%, transparent 50%),
        radial-gradient(ellipse at 80% 50%, rgba(20, 40, 60, 0.2) 0%, transparent 40%),
        radial-gradient(ellipse at 20% 80%, rgba(15, 30, 50, 0.2) 0%, transparent 40%);
      color: #e0e0e0;
      font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
    }
    .logo {
      font-size: 28px;
      font-weight: 300;
      letter-spacing: 8px;
      color: #ffffff;
      margin-bottom: 60px;
      text-transform: uppercase;
    }
    .logo span {
      font-weight: 600;
    }
    .container {
      text-align: center;
      padding: 48px 64px;
      background: rgba(10, 15, 25, 0.9);
      border: 1px solid rgba(60, 180, 200, 0.3);
      box-shadow:
        0 0 40px rgba(60, 180, 200, 0.1),
        inset 0 1px 0 rgba(255, 255, 255, 0.05);
    }
    h1 {
      color: #3bccd0;
      font-size: 18px;
      font-weight: 500;
      letter-spacing: 3px;
      text-transform: uppercase;
      margin-bottom: 16px;
    }
    p {
      color: #6a7a8a;
      font-size: 14px;
      font-weight: 400;
    }
  </style>
</head>
<body>
  <div class="logo"><span>MIMIR</span></div>
  <div class="container">
    <h1>Authenticated with Mimir Successfully</h1>
    <p>You can now close this page.</p>
  </div>
</body>
</html>
''';
}
