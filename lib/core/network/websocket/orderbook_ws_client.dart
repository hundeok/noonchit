// lib/core/network/websocket/orderbook_ws_client.dart

import 'dart:convert';
import '../../config/app_config.dart';
import 'base_ws_client.dart';

/// “호가” 스트림: List<Map<String, dynamic>>
class OrderbookWsClient extends BaseWsClient<List<Map<String, dynamic>>> {
  OrderbookWsClient({void Function(WsStatus)? onStatusChange})
      : super(
          url: AppConfig.upbitWsUrl,
          onStatusChange: onStatusChange,
          decode: BaseWsClient.decodeJsonList,
          encodeSubscribe: (markets) {
            final codes = markets.take(AppConfig.wsMaxSubscriptionCount).toList();
            return jsonEncode([
              {
                'ticket':
                    'orderbook-${DateTime.now().millisecondsSinceEpoch}'
              },
              {
                'type': 'orderbook',
                'codes': codes,
              },
              {'format': 'DEFAULT'},
            ]);
          },
        );
}
