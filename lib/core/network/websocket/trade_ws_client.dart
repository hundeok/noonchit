// lib/core/network/websocket/trade_ws_client.dart

import 'dart:convert';
import '../../config/app_config.dart';
import 'base_ws_client.dart';

/// “체결” 스트림: List<Map<String, dynamic>>
class TradeWsClient extends BaseWsClient<List<Map<String, dynamic>>> {
  TradeWsClient({void Function(WsStatus)? onStatusChange})
      : super(
          url: AppConfig.upbitWsUrl,
          onStatusChange: onStatusChange,
          decode: BaseWsClient.decodeJsonList,
          encodeSubscribe: (markets) {
            final codes = markets.take(AppConfig.wsMaxSubscriptionCount).toList();
            return jsonEncode([
              {
                'ticket': 'trade-${DateTime.now().millisecondsSinceEpoch}'
              },
              {
                'type': 'trade',
                'codes': codes,
              },
              {'format': 'DEFAULT'},
            ]);
          },
        );
}
