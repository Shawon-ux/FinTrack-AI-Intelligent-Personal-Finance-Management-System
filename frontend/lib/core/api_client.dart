import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiException implements Exception {
  final String message;
  final bool offline;
  ApiException(this.message, {this.offline = false});
  @override
  String toString() => message;
}

/// REST client with JWT access/refresh handling. Tokens live in secure storage.
class ApiClient {
  String? _access, _refresh;
  bool simulateOffline = false;
  final _store = const FlutterSecureStorage();
  final _http = http.Client();
  void Function()? onSessionExpired;

  /// Server address; defaults to the build-time API_BASE but can be changed in-app (saved on the device).
  String base = apiBase;

  Future<void> setBase(String url) async {
    base = url.trim().replaceAll(RegExp(r'/+$'), '');
    final p = await SharedPreferences.getInstance();
    await p.setString('api_base', base);
  }

  bool get hasSession => _refresh != null;

  Future<void> load() async {
    try {
      base = (await SharedPreferences.getInstance()).getString('api_base') ?? apiBase;
    } catch (_) {}
    try {
      _access = await _store.read(key: 'access');
      _refresh = await _store.read(key: 'refresh');
    } catch (_) {}
  }

  Future<void> setTokens(String access, String? refresh) async {
    _access = access;
    if (refresh != null) _refresh = refresh;
    try {
      await _store.write(key: 'access', value: access);
      if (refresh != null) await _store.write(key: 'refresh', value: refresh);
    } catch (_) {}
  }

  Future<void> clear() async {
    _access = _refresh = null;
    try {
      await _store.deleteAll();
    } catch (_) {}
  }

  String? get refreshToken => _refresh;

  Future<dynamic> get(String path) => send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => send('POST', path, body: body ?? {});
  Future<dynamic> patch(String path, Object body) => send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => send('DELETE', path);

  Future<dynamic> send(String method, String path, {Object? body, bool retry = true}) async {
    if (simulateOffline) throw ApiException('offline', offline: true);
    final req = http.Request(method, Uri.parse('$base/api/v1$path'));
    req.headers['Content-Type'] = 'application/json';
    if (_access != null) req.headers['Authorization'] = 'Bearer $_access';
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } catch (_) {
      throw ApiException('offline', offline: true);
    }
    if (res.statusCode == 401 && retry && _refresh != null && !path.startsWith('/auth/')) {
      if (await _refreshTokens()) return send(method, path, body: body, retry: false);
      onSessionExpired?.call();
      throw ApiException('Session expired');
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    final dynamic j = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) throw ApiException(_errorText(j));
    return j;
  }

  Future<bool> _refreshTokens() async {
    try {
      final r = await _http.post(Uri.parse('$base/api/v1/auth/token/refresh/'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh': _refresh}));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body);
      await setTokens(j['access'], j['refresh']);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _errorText(dynamic j) {
    if (j is Map) {
      final e = j['error'];
      if (e is Map) {
        if (e['message'] != null && e['message'] != 'Request failed') return '${e['message']}';
        final d = e['details'];
        if (d is Map && d.isNotEmpty) {
          final k = d.keys.first, v = d[k];
          final msg = v is List ? v.first : v;
          return k == 'detail' ? '$msg' : '$k: $msg';
        }
      }
      if (j['detail'] != null) return '${j['detail']}';
    }
    return 'Request failed';
  }
}
