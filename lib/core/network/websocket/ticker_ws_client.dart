// lib/core/network/websocket/ticker_ws_client.dart

import 'dart:convert';
import '../../config/app_config.dart';
import 'base_ws_client.dart';

/// “현재가” 스트림: List<Map<String, dynamic>>
class TickerWsClient extends BaseWsClient<List<Map<String, dynamic>>> {
  TickerWsClient({void Function(WsStatus)? onStatusChange})
      : super(
          url: AppConfig.upbitWsUrl,
          onStatusChange: onStatusChange,
          decode: BaseWsClient.decodeJsonList,
          encodeSubscribe: (markets) {
            final codes = markets.take(AppConfig.wsMaxSubscriptionCount).toList();
            return jsonEncode([
              {
                'ticket': 'ticker-${DateTime.now().millisecondsSinceEpoch}'
              },
              {
                'type': 'ticker',
                'codes': codes,
              },
              {'format': 'DEFAULT'},
            ]);
          },
        );
}
