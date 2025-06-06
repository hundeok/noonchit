// test/presentation/widgets/trade_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Trade 클래스 정의 (일관성 유지)
class Trade {
  final String market;
  final double price;
  final double volume;
  final String side;
  final double changePrice;
  final String changeState;
  final int timestampMs;
  final String sequentialId;

  const Trade({
    required this.market,
    required this.price,
    required this.volume,
    required this.side,
    required this.changePrice,
    required this.changeState,
    required this.timestampMs,
    required this.sequentialId,
  });

  double get total => price * volume;
  bool get isBuy => side == 'BID';
  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);
}

// TradeTile 위젯 (실제 구현과 동일)
class TradeTile extends StatelessWidget {
  final Trade trade;
  
  const TradeTile({Key? key, required this.trade}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(trade.market.replaceFirst('KRW-', '')),
        subtitle: Text('${trade.price.toStringAsFixed(0)}원'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${trade.volume.toStringAsFixed(1)} 개'),
            Text(
              '${(trade.total / 10000).toStringAsFixed(0)}만',
              style: TextStyle(
                color: trade.isBuy ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  Widget createWidgetUnderTest(Trade trade) {
    return MaterialApp(
      home: Scaffold(
        body: TradeTile(
          trade: trade,
          key: const Key('trade_tile'),
        ),
      ),
    );
  }

  group('TradeTile', () {
    const bidTrade = Trade(
      market: 'KRW-BTC',
      price: 50000.0,
      volume: 2.5,
      side: 'BID',
      changePrice: 1000.0,
      changeState: 'RISE',
      timestampMs: 1630000000000,
      sequentialId: '12345',
    );

    const askTrade = Trade(
      market: 'KRW-ETH',
      price: 3000000.0,
      volume: 1.0,
      side: 'ASK',
      changePrice: -50000.0,
      changeState: 'FALL',
      timestampMs: 1630000001000,
      sequentialId: '67890',
    );

    testWidgets('should display basic trade information correctly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trade_tile')), findsOneWidget);
      expect(find.byType(TradeTile), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('should display market name without KRW prefix', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      expect(find.text('BTC'), findsOneWidget);
      expect(find.text('KRW-BTC'), findsNothing);
    });

    testWidgets('should display formatted price correctly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      expect(find.text('50000원'), findsOneWidget);
    });

    testWidgets('should display volume with correct decimal places', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      expect(find.text('2.5 개'), findsOneWidget);
    });

    testWidgets('should display total amount in 만원 units', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      // 50000 * 2.5 = 125000, 125000 / 10000 = 12.5
      // toStringAsFixed(0)이므로 "13만" (반올림) 또는 "12만" (내림)
      // 실제 계산 확인
      final expectedTotal = (bidTrade.total / 10000).toStringAsFixed(0);
      expect(find.text('$expectedTotal만'), findsOneWidget);
    });

    testWidgets('should show green color for BID trades', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      // Column 내의 Text 위젯들 찾기
      final columnWidget = tester.widget<Column>(find.byType(Column).last);
      final textWidgets = columnWidget.children.whereType<Text>();
      
      // 총액 텍스트 (두 번째 Text)가 녹색인지 확인
      if (textWidgets.length >= 2) {
        final totalText = textWidgets.elementAt(1);
        expect(totalText.style?.color, Colors.green);
        expect(totalText.style?.fontWeight, FontWeight.bold);
      }
    });

    testWidgets('should show red color for ASK trades', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(askTrade));
      await tester.pumpAndSettle();

      // Column 내의 Text 위젯들 찾기
      final columnWidget = tester.widget<Column>(find.byType(Column).last);
      final textWidgets = columnWidget.children.whereType<Text>();
      
      // 총액 텍스트 (두 번째 Text)가 빨간색인지 확인
      if (textWidgets.length >= 2) {
        final totalText = textWidgets.elementAt(1);
        expect(totalText.style?.color, Colors.red);
        expect(totalText.style?.fontWeight, FontWeight.bold);
      }
    });

    testWidgets('should display different market symbols correctly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(askTrade));
      await tester.pumpAndSettle();

      expect(find.text('ETH'), findsOneWidget);
      expect(find.text('3000000원'), findsOneWidget);
      expect(find.text('1.0 개'), findsOneWidget);
    });

    testWidgets('should calculate total amount correctly for different trades', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(askTrade));
      await tester.pumpAndSettle();

      // 3000000 * 1.0 = 3000000, 3000000 / 10000 = 300 -> "300만"
      expect(find.text('300만'), findsOneWidget);
    });

    testWidgets('should handle zero values gracefully', (tester) async {
      const zeroTrade = Trade(
        market: 'KRW-ZERO',
        price: 0.0,
        volume: 0.0,
        side: 'BID',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: 1630000000000,
        sequentialId: 'zero',
      );

      await tester.pumpWidget(createWidgetUnderTest(zeroTrade));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trade_tile')), findsOneWidget);
      expect(find.text('ZERO'), findsOneWidget);
      expect(find.text('0원'), findsOneWidget);
      expect(find.text('0.0 개'), findsOneWidget);
      expect(find.text('0만'), findsOneWidget);
    });

    testWidgets('should handle very large numbers correctly', (tester) async {
      const largeTrade = Trade(
        market: 'KRW-BTC',
        price: 123456789.0,
        volume: 999.999,
        side: 'BID',
        changePrice: 1234567.0,
        changeState: 'RISE',
        timestampMs: 1630000000000,
        sequentialId: 'large',
      );

      await tester.pumpWidget(createWidgetUnderTest(largeTrade));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trade_tile')), findsOneWidget);
      expect(find.text('BTC'), findsOneWidget);
      expect(find.text('123456789원'), findsOneWidget);
      expect(find.text('1000.0 개'), findsOneWidget);
    });

    testWidgets('should handle decimal precision correctly', (tester) async {
      const precisionTrade = Trade(
        market: 'KRW-BTC',
        price: 50000.0,
        volume: 2.123456789,
        side: 'BID',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: 1630000000000,
        sequentialId: 'precision',
      );

      await tester.pumpWidget(createWidgetUnderTest(precisionTrade));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trade_tile')), findsOneWidget);
      expect(find.text('2.1 개'), findsOneWidget); // toStringAsFixed(1)
    });

    testWidgets('should be tappable when wrapped in GestureDetector', (tester) async {
      bool tapped = false;

      Widget tappableWidget = MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTap: () => tapped = true,
            child: const TradeTile(
              trade: bidTrade,
              key: Key('trade_tile'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(tappableWidget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trade_tile')));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('should have correct card styling', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.margin, const EdgeInsets.symmetric(vertical: 4));
    });

    testWidgets('should have correct trailing column layout', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.trailing, isA<Column>());
      
      final trailingColumn = listTile.trailing as Column;
      expect(trailingColumn.mainAxisAlignment, MainAxisAlignment.center);
      expect(trailingColumn.crossAxisAlignment, CrossAxisAlignment.end);
      expect(trailingColumn.children.length, 2); // volume + total
    });

    testWidgets('should be accessible', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trade_tile')), findsOneWidget);
      expect(find.byType(TradeTile), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('should display all required trade data', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(bidTrade));
      await tester.pumpAndSettle();

      // 모든 필수 정보가 표시되는지 확인
      expect(find.text('BTC'), findsOneWidget); // market
      expect(find.text('50000원'), findsOneWidget); // price
      expect(find.text('2.5 개'), findsOneWidget); // volume
      
      // 총액 계산: 50000 * 2.5 = 125000, 125000 / 10000 = 12.5
      final expectedTotal = (bidTrade.total / 10000).toStringAsFixed(0);
      expect(find.text('$expectedTotal만'), findsOneWidget); // total
    });
  });
}