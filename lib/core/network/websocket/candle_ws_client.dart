// lib/core/network/websocket/candle_ws_client.dart

import 'dart:convert';
import '../../config/app_config.dart';
import 'base_ws_client.dart';

/// “캔들” 스트림: List<Map<String, dynamic>>
/// [timeFrame]: e.g. "1m", "5m", "15m", ...
class CandleWsClient extends BaseWsClient<List<Map<String, dynamic>>> {
  CandleWsClient({
    required String timeFrame,
    void Function(WsStatus)? onStatusChange,
  }) : super(
          url: AppConfig.upbitWsUrl,
          onStatusChange: onStatusChange,
          decode: BaseWsClient.decodeJsonList,
          encodeSubscribe: (markets) {
            final codes = markets.take(AppConfig.wsMaxSubscriptionCount).toList();
            return jsonEncode([
              {
                'ticket':
                    'candle-$timeFrame-${DateTime.now().millisecondsSinceEpoch}'
              },
              {
                'type': 'candles_$timeFrame',
                'codes': codes,
              },
              {'format': 'DEFAULT'},
            ]);
          },
        );
}
