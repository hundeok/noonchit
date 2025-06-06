lib/
├── app.dart               # 앱 시작점 및 전체 설정
├── common/              # 공통 UI, 유틸리티, 상수, 확장
│   ├── widgets/           # 재사용 가능한 UI 컴포넌트
│   │   ├── loading_indicator.dart
│   │   ├── error_message.dart
│   │   ├── trade_status_chip.dart
│   │   └── ...
│   ├── utils/             # 범용적인 유틸리티 함수
│   │   ├── date_formatter.dart
│   │   ├── number_formatter.dart
│   │   ├── debouncer.dart
│   │   └── ...
│   ├── constants/         # 앱 전역 상수
│   │   ├── api_endpoints.dart
│   │   ├── app_colors.dart
│   │   ├── app_sizes.dart
│   │   └── ...
│   └── extensions/        # 확장 함수
│       ├── string_extensions.dart
│       ├── datetime_extensions.dart
│       └── ...
├── core/                # 핵심 로직, 서비스, 이벤트, DI, 에러 처리, 설정, 플랫폼
│   ├── event/             # 이벤트 추상 클래스 및 관련 믹스인, 구체 이벤트 정의
│   │   ├── app_events.dart
│   │   ├── event_mixin.dart
│   │   ├── market_events.dart       # SymbolsFetchedEvent
│   │   ├── trade_events.dart        # TradeReceivedEvent, SignificantTradeEvent
│   │   ├── api_events.dart          # ApiErrorEvent, ApiDisposedEvent
│   │   └── socket_events.dart       # WebSocketConnectedEvent, WebSocketClosedEvent
│   ├── api/             # REST API 통신 관련
│   │   ├── api_service.dart         # DioWrapper
│   │   ├── http_client.dart
│   │   ├── interceptors/
│   │   │   ├── auth_interceptor.dart
│   │   │   └── logging_interceptor.dart
│   │   └── exceptions/
│   │       ├── api_exception.dart
│   │       └── timeout_exception.dart
│   ├── socket/          # 소켓 통신 관련
│   │   ├── socket_service.dart      # WebSocketManager
│   │   ├── socket_state.dart        # SocketConnectionState
│   │   └── socket_event_handler.dart # 소켓 이벤트 처리 로직
│   ├── bridge/          # 데이터 변환 및 연결 (REST ↔ Socket), SignalBus (선택 사항)
│   │   ├── data_bridge.dart
│   │   └── signal_bus.dart        # 이벤트 기반 통신 (선택 사항)
│   ├── di/              # 의존성 주입
│   │   └── injection_container.dart # GetIt instance
│   ├── error/           # 공통 에러 모델
│   │   ├── failure.dart           # Either Failure
│   │   └── exception.dart         # Custom Exception
│   ├── config/          # 앱 환경 설정
│   │   ├── app_config.dart
│   │   └── env_config.dart         # .env 파일 처리
│   └── platform/        # 플랫폼별 서비스 추상화 및 구현 (선택 사항)
│       ├── platform_service.dart    # MethodChannel wrapper
│       ├── android/
│       │   └── android_platform_service.dart
│       └── ios/
│           └── ios_platform_service.dart
├── data/                # 데이터 저장소 인터페이스, 구현체, 모델, 데이터 소스
│   ├── repositories/    # 데이터 저장소 추상 인터페이스
│   │   ├── market_repository.dart
│   │   └── trade_repository.dart
│   ├── data_sources/    # 외부 데이터 소스 (API, Socket, Local)
│   │   ├── remote/
│   │   │   ├── market_api.dart
│   │   │   └── trade_api.dart
│   │   └── local/
│   │       ├── local_storage.dart     # SharedPreferencesWrapper
│   │       └── cache_manager.dart     # Hive or sqflite wrapper (선택 사항)
│   └── models/          # 데이터 모델 (DTO, Domain Model, JSON Serializable)
│       ├── market_model.dart
│       ├── trade_model.dart
│       └── ...
├── domain/              # 핵심 비즈니스 규칙, 엔티티, 유스케이스, 리포지토리 인터페이스
│   ├── entities/        # 핵심 비즈니스 객체
│   │   ├── market.dart
│   │   └── trade.dart
│   ├── use_cases/       # 비즈니스 로직 단위 (GetXService or Callable Class)
│   │   ├── get_live_trades.dart
│   │   └── fetch_symbols.dart
│   └── repositories/    # 데이터 저장소 추상 인터페이스 (data 레이어와 연결)
│       ├── market_repository.dart
│       └── trade_repository.dart
├── presentation/        # UI, 상태 관리, 라우팅, 테마, 국제화, 바인딩
│   ├── pages/           # 화면 단위 UI
│   │   ├── home_page.dart
│   │   └── trade_detail_page.dart
│   ├── widgets/         # 재사용 가능한 UI 컴포넌트 (common과 구분)
│   │   ├── trade_card.dart
│   │   └── symbol_item.dart
│   ├── controllers/     # 상태 관리 로직 (GetXController)
│   │   └── trade_controller.dart
│   ├── bindings/        # GetX Bindings (의존성 주입)
│   │   └── main_binding.dart
│   ├── routes/              # 라우팅 관리 (GetX Routes)
│   │   └── app_routes.dart
│   ├── theme/               # 앱 테마
│   │   ├── app_theme.dart
│   │   └── text_styles.dart
│   └── l10n/                # 국제화
│       ├── l10n.dart
│       ├── arb/
│       │   ├── en.arb
│       │   └── ko.arb
└── test/                # 유닛 테스트, 통합 테스트, 위젯 테스트
    ├── unit/
    │   ├── core/
    │   ├── data/
    │   └── domain/
    └── integration/
        └── app_flow_test.dart
tool/                # 개발 도구 및 스크립트
    └── build/
        └── build_runner.sh




다음 단계 (네 텅 빈 머리에 억지로 쑤셔 넣어준다!):

app.dart: 앱의 진입점을 만들고, 기본적인 앱 설정 (테마, 라우팅 초기화 등)을 한다! main() 함수를 만들고 runApp(MyApp())을 호출하는 기본적인 코드를 작성하라고!

common/: 재사용 가능한 UI 컴포넌트 (widgets), 유틸리티 함수 (utils), 전역 상수 (constants), 확장 함수 (extensions) 들을 실제로 구현해야 한다! UI 디자인을 참고해서 로딩 화면, 에러 메시지, 버튼 같은 기본적인 위젯들부터 만들고, 날짜/숫자 포맷팅 같은 유틸 함수들을 작성하라고!

core/: 핵심 로직과 관련된 코드들을 채워 넣어야 한다!

event/: 이벤트 정의를 기반으로 실제로 이벤트를 발생시키고 처리하는 로직을 구현해야 한다! 이벤트 버스를 만들고, 각 컴포넌트에서 이벤트를 발행하고 구독하는 방식을 설계하라고!
api/: REST API 통신을 위한 ApiService 를 구현하고, HTTP 클라이언트 설정, 인터셉터, 예외 처리 등을 작성해야 한다!
socket/: WebSocket 통신을 위한 SocketService 를 구현하고, 소켓 연결, 데이터 송수신, 에러 처리 등을 작성해야 한다!
bridge/: REST API와 WebSocket 사이의 데이터 변환 및 흐름 제어 로직을 구현하고, 필요하다면 SignalBus를 활용한 이벤트 중계 방식을 설계하라고!
di/: GetIt 같은 DI 컨테이너를 설정하고, 필요한 의존성들을 등록해야 한다!
error/: Failure 와 Exception 모델을 만들고, 에러 처리 전략을 구현해야 한다!
config/: 앱의 환경 설정 (API 키, 베이스 URL 등) 을 관리하는 방식을 구현해야 한다!
platform/: 필요한 플랫폼별 기능이 있다면 인터페이스를 정의하고, Android 와 iOS 폴더에 각각 구현체를 만들어야 한다!
data/: 데이터와 관련된 코드들을 채워 넣어야 한다!

repositories/: 도메인 레이어에서 사용할 데이터 접근 인터페이스를 정의한다!
data_sources/: remote/ (API, Socket) 와 local/ (로컬 저장소, 캐시) 에서 실제로 데이터를 가져오는 로직을 구현한다!
models/: API 응답 데이터 (DTO) 와 앱 내부에서 사용할 데이터 모델 (Domain Model) 을 정의하고, JSON 변환 로직을 구현해야 한다!
domain/: 핵심 비즈니스 로직을 구현해야 한다!

entities/: 핵심 비즈니스 객체들을 정의한다!
use_cases/: 비즈니스 로직 단위를 구현한다! (예: 실시간 체결 데이터 가져오기, 특정 종목 정보 가져오기 등)
repositories/: 데이터 접근 인터페이스를 정의한다! (data/repositories/ 와 이름은 같지만 역할이 다름!)
presentation/: UI 와 상태 관리를 담당하는 코드들을 채워 넣어야 한다!

pages/: 화면 단위 UI 를 구성한다!
widgets/: 재사용 가능한 UI 컴포넌트들을 만든다! (common/widgets/ 와 역할 구분!)
controllers/: 상태 관리 로직 (GetX Controller 등) 을 구현하고, UI 와 도메인 레이어를 연결한다!
bindings/: 의존성 주입 설정을 한다!
routes/: 앱의 화면 이동 (라우팅) 설정을 한다!
theme/: 앱의 디자인 테마 (색상, 폰트 등) 를 정의한다!
l10n/: 국제화 (다국어 지원) 설정을 한다!
test/: 유닛 테스트 와 통합 테스트 코드를 작성해서 각 기능과 전체적인 흐름을 검증해야 한다!

tool/: 빌드 자동화 스크립트 등을 작성해서 개발 편의성을 높인다!

## 💥 주요 흐름 타임라인

### ✅ 1. [이벤트 시스템의 진화]
- BaseEvent → SignalPayloadMixin → static const 최적화 → 제미니식 분리 아키텍처
- events.dart → domain별 세분화 (`market_event.dart`, `trade_event.dart`, ...)
- 결국 폴더 단위로 구분된 프로덕션 구조로 확장

### ✅ 2. [SignalBus / ApiService / SocketService 구조 고도화]
- 초기: 단순 `fire()`로 떼움
- 이후: EventBus → Observer 패턴 → HookRegistry → 수직 트리 구조 연동 논의
- SignalBus는 이제 전체 흐름의 **중심축**

### ✅ 3. [믹스인 도입과 구조 리팩토링]
- 믹스인 없이 클래스 반복 → 코드 중복 극심
- 믹스인 도입으로 공통 기능 추출 → 구조 개선
- 최종: `EventTypeMixin`, `EventPayloadMixin`, `EventSequentialIdMixin` 삼신기 완성

### ✅ 4. [아키텍처 인프라 완성 방향]
- Hook 시스템 (MetricsHook, LoggingHook, AlertHook 등)
- Lifecycle Hook + EventHook 연동
- 추후 분석/관측/알림 시스템으로 확장
- 제미니 기반 디렉토리 구조 적용 (lib/core, lib/domain, lib/data, lib/presentation 등)

### ✅ 5. [마음가짐과 철학의 전환]
- 이전까지는 “코드 돌려막기”, “퍼블리시만 하자” 수준
- 이제는 “한 줄도 모르고 쓰면 안 된다”, “망치를 내려놓고 칼을 간다”
- 기능 구현이 아니라 **이해 기반 설계**를 중심으로 회귀
- 클래식 음악의 정수를 향해 걸어가는 듯한 통찰

---

## 🧩 주요 기술 개념 정리 (한줄 설명)

| 개념 | 설명 |
|------|------|
| **Mixin** | 공통 기능을 클래스에 주입하기 위한 Dart 기능 |
| **Observer Pattern** | 상태 변경을 구독자들에게 자동 알림 (SignalBus 구조 핵심 기반) |
| **EventBus** | 앱 전체 이벤트 중앙 분산 처리기 |
| **Hook System** | 이벤트 발생 시 외부 시스템에 확장성 있게 후킹 |
| **Plugin System** | 런타임 확장성 확보를 위한 구조화된 모듈 로딩 방식 |
| **Domain Layer 분리** | UI, 데이터, 비즈니스 로직을 명확히 나눈 설계 철학 |
| **CQRS** | 명령(Command)과 조회(Query)를 구분하는 아키텍처 패턴 |
| **Tree 구조** | 이벤트 흐름이나 구성 요소를 노드 기반으로 계층화 관리 |
| **Equatable** | 객체 비교 시 값 기준으로 판단 (이벤트 중복 방지 목적) |
| **DSL (Domain Specific Language)** | 특정 목적에 최적화된 표현 방식의 언어, 이벤트 이름 등에서 부분 활용 |

---

├── app.dart
├── common
│   ├── constants
│   │   ├── api_endpoints.dart
│   │   ├── app_colors.dart
│   │   └── app_sizes.dart
│   ├── extensions
│   │   ├── datetime_extensions.dart
│   │   └── string_extensions.dart
│   ├── utils
│   │   ├── date_formatter.dart
│   │   ├── debouncer.dart
│   │   └── number_formatter.dart
│   └── widgets
│       ├── error_message.dart
│       ├── loading_indicator.dart
│       └── trade_status_chip.dart
├── core
│   ├── api
│   │   ├── api_service.dart
│   │   ├── exceptions
│   │   ├── http_client.dart
│   │   └── interceptors
│   ├── auth
│   │   ├── auth_token_manager.dart
│   │   └── secure_auth_token_manager.dart
│   ├── bridge
│   │   ├── data_bridge.dart
│   │   └── signal_bus.dart
│   ├── config
│   │   ├── app_config.dart
│   │   └── env_config.dart
│   ├── di
│   │   └── injection_container.dart
│   ├── error
│   │   ├── exception.dart
│   │   └── failure.dart
│   ├── event
│   │   ├── api_events.dart
│   │   ├── app_events.dart
│   │   ├── event_mixin.dart
│   │   ├── market_events.dart
│   │   ├── socket_events.dart
│   │   └── trade_events.dart
│   ├── platform
│   │   ├── android
│   │   ├── ios
│   │   └── platform_service.dart
│   ├── services
│   │   └── trade_console_logger_service.dart
│   └── socket
│       ├── socket_event_handler.dart
│       ├── socket_service.dart
│       └── socket_state.dart
├── data
│   ├── data_sources
│   │   ├── local
│   │   └── remote
│   ├── models
│   │   ├── market_model.dart
│   │   └── trade_model.dart
│   └── repositories
│       ├── market_repository.dart
│       └── trade_repository.dart
├── domain
│   ├── entities
│   │   ├── market.dart
│   │   ├── trade.dart
│   │   ├── upbit_market_symbol.dart
│   │   └── upbit_trade.dart
│   ├── repositories
│   │   ├── market_repository.dart
│   │   └── trade_repository.dart
│   └── use_cases
│       ├── fetch_symbols.dart
│       └── get_live_trades.dart
├── main.dart
├── presentation
│   ├── bindings
│   │   └── main_binding.dart
│   ├── controllers
│   │   └── trade_controller.dart
│   ├── l10n
│   │   ├── arb
│   │   └── l10n.dart
│   ├── pages
│   │   ├── home_page.dart
│   │   └── trade_detail_page.dart
│   ├── routes
│   │   └── app_routes.dart
│   ├── theme
│   │   ├── app_theme.dart
│   │   └── text_styles.dart
│   └── widgets
│       ├── symbol_item.dart
│       └── trade_card.dart
├── project_tree.txt
├── test
│   ├── integration
│   │   └── app_flow_test.dart
│   └── unit
│       ├── core
│       ├── data
│       └── domain
└── tool





lib
├─ app.dart
├─ main.dart
├─ core
│  ├─ bridge
│  │   └─ signal_bus.dart
│  ├─ config
│  │   └─ app_config.dart
│  ├─ di
│  │   └─ providers.dart
│  ├─ error
│  │   └─ app_exception.dart
│  ├─ extensions
│  │   └─ result.dart
│  └─ network
│      ├─ api_client.dart
│      ├─ web_socket_client.dart
│      └─ (client/interceptors 폴더는 추후 필요시 자동 생성)
├─ shared
│  ├─ theme
│  │   └─ app_theme.dart
│  ├─ utils
│  │   ├─ date_time.dart
│  │   └─ logger.dart
│  └─ widgets
│      └─ common_app_bar.dart
└─ features
    ├─ trade
    │   ├─ data
    │   │   ├─ datasources
    │   │   │   └─ trade_remote_ds.dart
    │   │   ├─ models
    │   │   │   └─ trade_dto.dart
    │   │   └─ repositories
    │   │       └─ trade_repository_impl.dart
    │   ├─ domain
    │   │   ├─ entities
    │   │   │   └─ trade.dart
    │   │   ├─ repositories
    │   │   │   └─ trade_repository.dart
    │   │   └─ usecases
    │   │       └─ watch_trades.dart
    │   └─ presentation
    │       ├─ providers
    │       │   └─ trade_provider.dart
    │       ├─ pages
    │       │   └─ trade_page.dart
    │       └─ widgets
    │           └─ trade_tile.dart
    ├─ surge (empty scaffolds, 채우기만 남음)
    ├─ volume (…)
    ├─ momentary (…)
    └─ settings
        ├─ domain
        │   └─ entities
        │       └─ app_settings.dart
        └─ presentation
            ├─ providers
            │   └─ settings_provider.dart
            └─ pages
                └─ settings_page.dart
test
├─ core/network/api_client_test.dart
├─ features
│   ├─ trade
│   │   ├─ data/trade_repository_impl_test.dart
│   │   └─ presentation/trade_provider_test.dart
│   ├─ surge (placeholder)
│   ├─ volume (placeholder)
│   └─ momentary (placeholder)
└─ shared/widgets/common_app_bar_test.dart
