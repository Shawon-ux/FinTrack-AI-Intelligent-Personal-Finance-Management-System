import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

typedef J = Map<String, dynamic>;

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

List<J> asList(dynamic j) {
  final l = j is List ? j : (j is Map ? (j['results'] ?? []) : []);
  return List<J>.from((l as List).map((e) => Map<String, dynamic>.from(e)));
}

// ---------------- auth ----------------
class AuthNotifier extends StateNotifier<J?> {
  AuthNotifier(this.ref) : super(null);
  final Ref ref;
  ApiClient get api => ref.read(apiProvider);

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    final u = p.getString('user');
    if (u != null && api.hasSession) state = jsonDecode(u);
    api.onSessionExpired = () => logout(silent: true);
  }

  Future<void> authenticate(String kind, String email, String password, {String? name}) async {
    final j = await api.post('/auth/$kind/', {'email': email, 'password': password, if (name != null) 'name': name});
    await api.setTokens(j['access'], j['refresh']);
    await _clearLocal();
    state = Map<String, dynamic>.from(j['user']);
    final p = await SharedPreferences.getInstance();
    await p.setString('user', jsonEncode(state));
    await ref.read(txProvider.notifier).init();
  }

  /// Creates the account but does NOT sign in - the user logs in afterwards.
  Future<void> register(String email, String password, {String? name}) async {
    await api.post('/auth/register/', {'email': email, 'password': password, if (name != null && name.isNotEmpty) 'name': name});
  }

  Future<void> reloadMe() async {
    try {
      state = Map<String, dynamic>.from(await api.get('/users/me/'));
      (await SharedPreferences.getInstance()).setString('user', jsonEncode(state));
    } catch (_) {}
  }

  Future<void> updateMe({String? name, J? profile}) async {
    state = Map<String, dynamic>.from(await api.patch('/users/me/', {if (name != null) 'name': name, if (profile != null) 'profile': profile}));
    (await SharedPreferences.getInstance()).setString('user', jsonEncode(state));
  }

  Future<void> saveProfile(J profile) async {
    state = Map<String, dynamic>.from(await api.patch('/users/me/', {'profile': profile}));
    (await SharedPreferences.getInstance()).setString('user', jsonEncode(state));
  }

  Future<void> _clearLocal() async {
    final p = await SharedPreferences.getInstance();
    for (final k in ['user', 'tx_cache', 'tx_queue', 'overview']) {
      await p.remove(k);
    }
  }

  Future<void> logout({bool silent = false}) async {
    if (!silent && api.refreshToken != null) {
      try {
        await api.post('/auth/logout/', {'refresh': api.refreshToken});
      } catch (_) {}
    }
    await api.clear();
    await _clearLocal();
    state = null;
    await ref.read(txProvider.notifier).init();
  }

  Future<void> deleteAccount() async {
    await api.delete('/users/me/delete/');
    await logout(silent: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, J?>((ref) => AuthNotifier(ref));

// ---------------- offline-first transactions ----------------
class TxState {
  final List<J> cache, queue;
  final bool syncing, offline;
  const TxState({this.cache = const [], this.queue = const [], this.syncing = false, this.offline = false});
  TxState copyWith({List<J>? cache, List<J>? queue, bool? syncing, bool? offline}) => TxState(
      cache: cache ?? this.cache, queue: queue ?? this.queue, syncing: syncing ?? this.syncing, offline: offline ?? this.offline);

  /// Server copy overlaid with pending local changes (deletes removed).
  List<J> get merged {
    final m = <String, J>{for (final t in cache) t['id']: t};
    for (final q in queue) {
      final tx = Map<String, dynamic>.from(q['tx']);
      if (q['op'] == 'delete') {
        m.remove(tx['id']);
      } else {
        m[tx['id']] = {...?m[tx['id']], ...tx, 'sync_status': 'pending'};
      }
    }
    final l = m.values.toList();
    l.sort((a, b) => b['transaction_date'].toString().compareTo(a['transaction_date'].toString()));
    return l;
  }
}

class TxNotifier extends StateNotifier<TxState> {
  TxNotifier(this.ref) : super(const TxState());
  final Ref ref;
  Timer? _timer;
  ApiClient get api => ref.read(apiProvider);

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    List<J> dec(String k) => (jsonDecode(p.getString(k) ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)).toList();
    state = state.copyWith(cache: dec('tx_cache'), queue: dec('tx_queue'));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tx_cache', jsonEncode(state.cache.take(300).toList()));
    await p.setString('tx_queue', jsonEncode(state.queue));
  }

  void setOffline(bool v) {
    api.simulateOffline = v;
    state = state.copyWith(offline: v);
    if (!v) sync();
  }

  Future<void> _enqueue(String op, J tx) async {
    final id = tx['id'];
    state = state.copyWith(queue: [
      ...state.queue.where((q) => q['tx']['id'] != id),
      {'op': op, 'tx': tx}
    ]);
    await _persist();
    unawaited(sync());
  }

  Future<void> upsert(J tx) => _enqueue('upsert', tx);
  Future<void> remove(String id) => _enqueue('delete', {'id': id});

  Future<void> refresh() async {
    try {
      final j = await api.get('/transactions/?ordering=-transaction_date');
      state = state.copyWith(cache: asList(j).map((t) => {...t, 'sync_status': 'synced'}).toList());
      await _persist();
    } on ApiException {/* offline: keep cache */}
  }

  /// Returns a status message. Success is decided by the server's response, never by connectivity.
  Future<String?> sync() async {
    if (state.syncing || state.queue.isEmpty || api.simulateOffline || !api.hasSession) return null;
    state = state.copyWith(syncing: true);
    String? msg;
    try {
      final payload = state.queue.map((q) => q['op'] == 'delete' ? {'id': q['tx']['id'], '_deleted': true} : q['tx']).toList();
      final res = await api.post('/transactions/bulk-sync/', {'transactions': payload});
      final ok = Set<String>.from((res['synced'] as List).map((e) => '$e'));
      state = state.copyWith(queue: state.queue.where((q) => !ok.contains(q['tx']['id'])).toList());
      await _persist();
      msg = (res['failed'] as List).isEmpty ? 'Synced ${ok.length} item(s)' : '${(res['failed'] as List).length} failed - will retry';
      state = state.copyWith(syncing: false);
      await refresh();
    } on ApiException catch (e) {
      msg = e.offline ? null : e.message;
    } finally {
      state = state.copyWith(syncing: false);
    }
    return msg;
  }
}

final txProvider = StateNotifierProvider<TxNotifier, TxState>((ref) => TxNotifier(ref));

// ---------------- read models (cached fallback for the dashboard) ----------------
final overviewProvider = FutureProvider.autoDispose<J>((ref) async {
  final api = ref.read(apiProvider);
  final p = await SharedPreferences.getInstance();
  try {
    final j = Map<String, dynamic>.from(await api.get('/analytics/overview/'));
    await p.setString('overview', jsonEncode(j));
    j['_stale'] = false;
    return j;
  } on ApiException catch (e) {
    final c = p.getString('overview');
    if (e.offline && c != null) return {...jsonDecode(c), '_stale': true};
    rethrow;
  }
});

final accountsProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/accounts/')));
final budgetsProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/budgets/summary/')));
final goalsProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/goals/')));
final recurringProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/recurring/')));
final notificationsProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/notifications/')));
final forecastProvider = FutureProvider.autoDispose<J>((ref) async => Map<String, dynamic>.from(await ref.read(apiProvider).get('/ai/predictions/spending/')));
final anomaliesProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/ai/anomalies/')));
final trendsProvider = FutureProvider.autoDispose<J>((ref) async => Map<String, dynamic>.from(await ref.read(apiProvider).get('/analytics/trends/')));

String fmt(num? n) {
  final v = (n ?? 0).round().abs();
  final s = v.toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final head = s.substring(0, s.length - 3), tail = s.substring(s.length - 3);
    out = '${head.replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},')},$tail';
  }
  return '${(n ?? 0) < 0 ? '-' : ''}৳$out';
}

String errText(Object e) => e is ApiException ? (e.offline ? 'You are offline - this needs a connection' : e.message) : '$e';
bool get isWeb => kIsWeb;
