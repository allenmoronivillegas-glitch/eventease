import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

const _desktopClientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
const _callbackTimeout = Duration(minutes: 3);

Future<UserCredential?> signInWithGoogleOnWindows() async {
  if (_desktopClientId.isEmpty) {
    throw FirebaseAuthException(
      code: 'google-desktop-not-configured',
      message: 'Set GOOGLE_DESKTOP_CLIENT_ID to a Desktop OAuth client ID from the EventEase Google Cloud project.',
    );
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final httpClient = HttpClient();

  try {
    final redirectUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
    );
    final state = _randomUrlSafeString(32);
    final verifier = _randomUrlSafeString(48);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final authorizationUri = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'client_id': _desktopClientId,
        'redirect_uri': redirectUri.toString(),
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'prompt': 'select_account',
      },
    );

    final callbackFuture = server.first.timeout(_callbackTimeout);
    final opened = await launchUrl(
      authorizationUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw FirebaseAuthException(
        code: 'google-oauth-browser-launch-failed',
        message: 'Could not open a browser for Google sign-in.',
      );
    }

    final callback = await callbackFuture;
    final query = callback.uri.queryParameters;
    final response = callback.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><html><head><title>EventEase</title></head>'
        '<body><p>You can close this tab and return to EventEase.</p></body></html>',
      );
    await response.close();

    if (callback.uri.path != '/' || query['state'] != state) {
      throw FirebaseAuthException(
        code: 'google-oauth-invalid-state',
        message: 'Google sign-in could not verify the browser response. Please try again.',
      );
    }
    if (query['error'] == 'access_denied') return null;
    if (query['error'] case final String oauthError) {
      throw FirebaseAuthException(
        code: 'google-oauth-failed',
        message:
            query['error_description'] ??
            'Google sign-in failed ($oauthError). Please try again.',
      );
    }

    final authorizationCode = query['code'];
    if (authorizationCode == null || authorizationCode.isEmpty) {
      throw FirebaseAuthException(
        code: 'google-oauth-missing-code',
        message:
            'Google did not return an authorization code. Please try again.',
      );
    }

    final tokenRequest = await httpClient.postUrl(
      Uri.https('oauth2.googleapis.com', '/token'),
    );
    tokenRequest.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    tokenRequest.write(
      Uri(
        queryParameters: {
          'client_id': _desktopClientId,
          'code': authorizationCode,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri.toString(),
        },
      ).query,
    );

    final tokenResponse = await tokenRequest.close();
    final responseBody = await utf8.decoder.bind(tokenResponse).join();
    if (tokenResponse.statusCode != HttpStatus.ok) {
      throw FirebaseAuthException(
        code: 'google-oauth-token-exchange-failed',
        message: 'Google could not exchange the authorization code. Check the Desktop OAuth client configuration and try again.',
      );
    }

    final tokenData = jsonDecode(responseBody);
    if (tokenData is! Map<String, dynamic>) {
      throw FirebaseAuthException(
        code: 'google-oauth-token-exchange-failed',
        message: 'Google returned an invalid token response.',
      );
    }

    final idToken = tokenData['id_token'];
    final accessToken = tokenData['access_token'];
    if (idToken is! String || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token. Check the Desktop OAuth client configuration.',
      );
    }

    return await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken is String ? accessToken : null,
      ),
    );
  } on TimeoutException {
    throw FirebaseAuthException(
      code: 'google-oauth-timeout',
      message:
          'Google sign-in timed out before the browser returned to EventEase.',
    );
  } finally {
    await server.close(force: true);
    httpClient.close(force: true);
  }
}

String _randomUrlSafeString(int byteCount) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
