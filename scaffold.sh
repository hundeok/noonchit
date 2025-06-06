#!/usr/bin/env bash
set -e

echo "🧹  clean old sources"
rm -rf lib test                         # 싹 비움

echo "📁  create directories"
# ── lib ────────────────────────────────────────────────
mkdir -p \
  lib/{core/{config,network,bridge,extensions,error},shared/{utils,widgets},features,} \
  lib/core/network/{datasources,interceptors,client}   # 세부 depth

# feature 공통 하위폴더
for f in trade surge volume momentary; do
  mkdir -p lib/features/${f}/{data/{datasources,models,repositories},domain/{entities,repositories,usecases},presentation/{providers,pages,widgets}}
done
mkdir -p lib/features/settings/{domain/entities,presentation/{providers,pages}}

# ── test ───────────────────────────────────────────────
mkdir -p \
  test/core/network \
  test/features/{trade/{data,presentation},surge,volume,momentary} \
  test/shared/widgets

echo "📄  scaffold files with minimal content"

# ---------- top-level ----------
cat > lib/app.dart <<'DART'
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/config/app_config.dart';
import 'shared/theme/app_theme.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/trade/presentation/pages/trade_page.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const TradePage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  ],
);

class NoonchitApp extends StatelessWidget {
  const NoonchitApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: AppConfig.appName,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      );
}
DART

cat > lib/main.dart <<'DART'
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: NoonchitApp()));
}
DART

# ---------- core ----------
cat > lib/core/config/app_config.dart <<'DART'
class AppConfig {
  static const String appName = 'Noonchit';
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
}
DART

cat > lib/core/network/api_client.dart <<'DART'
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }
  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  Dio get dio => _dio;
}
DART

cat > lib/core/network/web_socket_client.dart <<'DART'
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketClient {
  WebSocketChannel connect(String url) => WebSocketChannel.connect(Uri.parse(url));
}
DART

cat > lib/core/error/app_exception.dart <<'DART'
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => '$runtimeType: $message';
}
DART

cat > lib/core/bridge/signal_bus.dart <<'DART'
import 'dart:async';

class SignalBus {
  SignalBus._();
  static final SignalBus I = SignalBus._();
  final _ctrl = StreamController.broadcast();
  Stream<T> on<T>() => _ctrl.stream.where((e) => e is T).cast<T>();
  void fire(Object event) => _ctrl.add(event);
}
DART

cat > lib/core/extensions/result.dart <<'DART'
sealed class Result<T, E> {
  const Result();
  R fold<R>(R Function(T) ok, R Function(E) err);
}

final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
  @override
  R fold<R>(R Function(T) ok, R Function(E) err) => ok(value);
}

final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
  @override
  R fold<R>(R Function(T) ok, R Function(E) err) => err(error);
}
DART

# ---------- shared ----------
cat > lib/shared/utils/logger.dart <<'DART'
import 'dart:developer' as dev;
void log(String msg, {Object? error, StackTrace? st}) =>
    dev.log(msg, name: 'Noonchit', error: error, stackTrace: st);
DART

cat > lib/shared/utils/date_time.dart <<'DART'
extension DateTimeX on DateTime {
  String toIsoSec() => toIso8601String().split('.').first;
}
DART

cat > lib/shared/widgets/common_app_bar.dart <<'DART'
import 'package:flutter/material.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';

class CommonAppBar extends AppBar {
  CommonAppBar({super.key, required String title})
      : super(
          title: Text(title),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(_navKey.currentContext!).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            )
          ],
        );
}
final _navKey = GlobalKey<NavigatorState>();
DART

# ---------- features / trade (샘플로 꽉 채움) ----------
cat > lib/features/trade/domain/entities/trade.dart <<'DART'
class Trade {
  const Trade({
    required this.market,
    required this.price,
    required this.volume,
    required this.isBuy,
    required this.timestamp,
  });
  final String market;
  final double price;
  final double volume;
  final bool isBuy;
  final DateTime timestamp;
}
DART

cat > lib/features/trade/data/models/trade_dto.dart <<'DART'
import '../../domain/entities/trade.dart';

class TradeDto {
  TradeDto({
    required this.market,
    required this.price,
    required this.volume,
    required this.isBuy,
    required this.timestamp,
  });
  final String market;
  final double price;
  final double volume;
  final bool isBuy;
  final int timestamp;

  factory TradeDto.fromJson(Map<String, dynamic> j) => TradeDto(
        market: j['cd'] as String,
        price: (j['tp'] as num).toDouble(),
        volume: (j['tv'] as num).toDouble(),
        isBuy: j['ab'] == 'BID',
        timestamp: j['ttms'] as int,
      );

  Trade toDomain() => Trade(
        market: market,
        price: price,
        volume: volume,
        isBuy: isBuy,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
}
DART

cat > lib/features/trade/domain/repositories/trade_repository.dart <<'DART'
import '../entities/trade.dart';

abstract interface class TradeRepository {
  Stream<Trade> watch(List<String> markets);
}
DART

cat > lib/features/trade/data/datasources/trade_remote_ds.dart <<'DART'
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/trade_dto.dart';

class TradeRemoteDatasource {
  TradeRemoteDatasource(this._channel);
  final WebSocketChannel _channel;

  Stream<TradeDto> watch(List<String> markets) {
    _channel.sink.add(jsonEncode([
      {'ticket': 'noonchit'},
      {'type': 'trade', 'codes': markets},
    ]));

    return _channel.stream
        .map((e) => e is List<int> ? utf8.decode(e) : e as String)
        .map((raw) => TradeDto.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }
}
DART

cat > lib/features/trade/data/repositories/trade_repository_impl.dart <<'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../datasources/trade_remote_ds.dart';

class TradeRepositoryImpl implements TradeRepository {
  TradeRepositoryImpl(this._ds);
  final TradeRemoteDatasource _ds;

  @override
  Stream<Trade> watch(List<String> markets) =>
      _ds.watch(markets).map((dto) => dto.toDomain());
}
DART

cat > lib/features/trade/domain/usecases/watch_trades.dart <<'DART'
import '../entities/trade.dart';
import '../repositories/trade_repository.dart';

class WatchTrades {
  WatchTrades(this._repo);
  final TradeRepository _repo;

  Stream<Trade> call(List<String> markets) => _repo.watch(markets);
}
DART

cat > lib/features/trade/presentation/providers/trade_provider.dart <<'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/trade.dart';
import '../../domain/usecases/watch_trades.dart';

class TradeState extends AsyncValue<List<Trade>> {
  const TradeState.loading() : super.loading();
  const TradeState.data(List<Trade> data) : super.data(data);
  const TradeState.error(Object e, StackTrace st) : super.error(e, st);
}

class TradeNotifier extends StateNotifier<TradeState> {
  TradeNotifier(this._watchTrades) : super(const TradeState.loading());

  final WatchTrades _watchTrades;
  StreamSubscription? _sub;

  void start(List<String> markets) {
    _sub?.cancel();
    state = const TradeState.loading();
    _sub = _watchTrades(markets).listen(
      (trade) {
        final current = (state is AsyncData<List<Trade>>)
            ? (state as AsyncData<List<Trade>>).value
            : <Trade>[];
        state = TradeState.data([trade, ...current].take(200).toList());
      },
      onError: (e, st) => state = TradeState.error(e, st),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
DART

cat > lib/features/trade/presentation/pages/trade_page.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trade_provider.dart';
import '../widgets/trade_tile.dart';

class TradePage extends ConsumerWidget {
  const TradePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tradeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('체결 포착')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (trades) => ListView.builder(
          itemCount: trades.length,
          itemBuilder: (_, i) => TradeTile(trade: trades[i]),
        ),
      ),
    );
  }
}
DART

cat > lib/features/trade/presentation/widgets/trade_tile.dart <<'DART'
import 'package:flutter/material.dart';
import '../../domain/entities/trade.dart';

class TradeTile extends StatelessWidget {
  const TradeTile({super.key, required this.trade});
  final Trade trade;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(trade.market),
        subtitle: Text(
            '${trade.isBuy ? 'BUY' : 'SELL'}  ${trade.price.toStringAsFixed(0)}'),
        trailing: Text('${trade.volume.toStringAsFixed(2)}'),
      );
}
DART

# ---------- settings (sample) ----------
cat > lib/features/settings/domain/entities/app_settings.dart <<'DART'
class AppSettings {
  const AppSettings({required this.themeMode});
  final ThemeMode themeMode;
  AppSettings copyWith({ThemeMode? themeMode}) =>
      AppSettings(themeMode: themeMode ?? this.themeMode);
}
DART

cat > lib/features/settings/presentation/providers/settings_provider.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_settings.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings(themeMode: ThemeMode.system));
  void setTheme(ThemeMode mode) => state = state.copyWith(themeMode: mode);
}
DART

cat > lib/features/settings/presentation/pages/settings_page.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListTile(
        title: const Text('Theme'),
        trailing: DropdownButton<ThemeMode>(
          value: settings.themeMode,
          items: const [
            DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
            DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
          ],
          onChanged: (m) => ref.read(settingsProvider.notifier).setTheme(m!),
        ),
      ),
    );
  }
}
DART

# ---------- shared theme ----------
cat > lib/shared/theme/app_theme.dart <<'DART'
import 'package:flutter/material.dart';
class AppTheme {
  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: Colors.orange,
    useMaterial3: true,
  );
  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.orange,
    useMaterial3: true,
  );
}
DART

# ---------- provider wiring ----------
cat > lib/core/di/providers.dart <<'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/trade/data/datasources/trade_remote_ds.dart';
import '../../features/trade/data/repositories/trade_repository_impl.dart';
import '../../features/trade/domain/usecases/watch_trades.dart';
import '../../features/trade/presentation/providers/trade_provider.dart';
import '../network/web_socket_client.dart';

// WebSocket
final wsClientProvider = Provider((_) => WebSocketClient());

// Trade
final tradeRemoteDsProvider = Provider((ref) =>
    TradeRemoteDatasource(ref.read(wsClientProvider).connect('wss://api.upbit.com/websocket/v1')));

final tradeRepoProvider =
    Provider((ref) => TradeRepositoryImpl(ref.read(tradeRemoteDsProvider)));

final watchTradesProvider =
    Provider((ref) => WatchTrades(ref.read(tradeRepoProvider)));

final tradeProvider =
    StateNotifierProvider<TradeNotifier, TradeState>((ref) =>
        TradeNotifier(ref.read(watchTradesProvider))..start(['KRW-BTC']));
DART

# ---------- tests (빈 템플릿) ----------
for f in \
  test/core/network/api_client_test.dart \
  test/features/trade/data/trade_repository_impl_test.dart \
  test/features/trade/presentation/trade_provider_test.dart \
  test/shared/widgets/common_app_bar_test.dart; do
  cat > $f <<'DART'
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('example test', () {
    expect(1 + 1, 2);
  });
}
DART
done

echo "✅  scaffold complete"
