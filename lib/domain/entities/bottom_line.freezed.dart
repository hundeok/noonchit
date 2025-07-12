// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bottom_line.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MarketSnapshot {
  DateTime get timestamp => throw _privateConstructorUsedError;
  String get timeFrame => throw _privateConstructorUsedError;
  List<Trade> get topTrades =>
      throw _privateConstructorUsedError; // ≥20M, 최근 50건
  List<Volume> get topVolumes =>
      throw _privateConstructorUsedError; // 활성 마켓 상위 50개
  List<Surge> get surges => throw _privateConstructorUsedError; // 변화 있는 코인만
  List<Volume> get sectorVolumes =>
      throw _privateConstructorUsedError; // 주요 섹터 10개
  Map<String, double> get volChangePct =>
      throw _privateConstructorUsedError; // 볼륨 변화율
  Map<String, double> get sectorShareDelta =>
      throw _privateConstructorUsedError; // 섹터 점유율 변화 (수정됨)
  Map<String, double> get priceDelta => throw _privateConstructorUsedError;

  /// Create a copy of MarketSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarketSnapshotCopyWith<MarketSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarketSnapshotCopyWith<$Res> {
  factory $MarketSnapshotCopyWith(
          MarketSnapshot value, $Res Function(MarketSnapshot) then) =
      _$MarketSnapshotCopyWithImpl<$Res, MarketSnapshot>;
  @useResult
  $Res call(
      {DateTime timestamp,
      String timeFrame,
      List<Trade> topTrades,
      List<Volume> topVolumes,
      List<Surge> surges,
      List<Volume> sectorVolumes,
      Map<String, double> volChangePct,
      Map<String, double> sectorShareDelta,
      Map<String, double> priceDelta});
}

/// @nodoc
class _$MarketSnapshotCopyWithImpl<$Res, $Val extends MarketSnapshot>
    implements $MarketSnapshotCopyWith<$Res> {
  _$MarketSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarketSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? timeFrame = null,
    Object? topTrades = null,
    Object? topVolumes = null,
    Object? surges = null,
    Object? sectorVolumes = null,
    Object? volChangePct = null,
    Object? sectorShareDelta = null,
    Object? priceDelta = null,
  }) {
    return _then(_value.copyWith(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timeFrame: null == timeFrame
          ? _value.timeFrame
          : timeFrame // ignore: cast_nullable_to_non_nullable
              as String,
      topTrades: null == topTrades
          ? _value.topTrades
          : topTrades // ignore: cast_nullable_to_non_nullable
              as List<Trade>,
      topVolumes: null == topVolumes
          ? _value.topVolumes
          : topVolumes // ignore: cast_nullable_to_non_nullable
              as List<Volume>,
      surges: null == surges
          ? _value.surges
          : surges // ignore: cast_nullable_to_non_nullable
              as List<Surge>,
      sectorVolumes: null == sectorVolumes
          ? _value.sectorVolumes
          : sectorVolumes // ignore: cast_nullable_to_non_nullable
              as List<Volume>,
      volChangePct: null == volChangePct
          ? _value.volChangePct
          : volChangePct // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      sectorShareDelta: null == sectorShareDelta
          ? _value.sectorShareDelta
          : sectorShareDelta // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      priceDelta: null == priceDelta
          ? _value.priceDelta
          : priceDelta // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MarketSnapshotImplCopyWith<$Res>
    implements $MarketSnapshotCopyWith<$Res> {
  factory _$$MarketSnapshotImplCopyWith(_$MarketSnapshotImpl value,
          $Res Function(_$MarketSnapshotImpl) then) =
      __$$MarketSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime timestamp,
      String timeFrame,
      List<Trade> topTrades,
      List<Volume> topVolumes,
      List<Surge> surges,
      List<Volume> sectorVolumes,
      Map<String, double> volChangePct,
      Map<String, double> sectorShareDelta,
      Map<String, double> priceDelta});
}

/// @nodoc
class __$$MarketSnapshotImplCopyWithImpl<$Res>
    extends _$MarketSnapshotCopyWithImpl<$Res, _$MarketSnapshotImpl>
    implements _$$MarketSnapshotImplCopyWith<$Res> {
  __$$MarketSnapshotImplCopyWithImpl(
      _$MarketSnapshotImpl _value, $Res Function(_$MarketSnapshotImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarketSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? timeFrame = null,
    Object? topTrades = null,
    Object? topVolumes = null,
    Object? surges = null,
    Object? sectorVolumes = null,
    Object? volChangePct = null,
    Object? sectorShareDelta = null,
    Object? priceDelta = null,
  }) {
    return _then(_$MarketSnapshotImpl(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timeFrame: null == timeFrame
          ? _value.timeFrame
          : timeFrame // ignore: cast_nullable_to_non_nullable
              as String,
      topTrades: null == topTrades
          ? _value._topTrades
          : topTrades // ignore: cast_nullable_to_non_nullable
              as List<Trade>,
      topVolumes: null == topVolumes
          ? _value._topVolumes
          : topVolumes // ignore: cast_nullable_to_non_nullable
              as List<Volume>,
      surges: null == surges
          ? _value._surges
          : surges // ignore: cast_nullable_to_non_nullable
              as List<Surge>,
      sectorVolumes: null == sectorVolumes
          ? _value._sectorVolumes
          : sectorVolumes // ignore: cast_nullable_to_non_nullable
              as List<Volume>,
      volChangePct: null == volChangePct
          ? _value._volChangePct
          : volChangePct // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      sectorShareDelta: null == sectorShareDelta
          ? _value._sectorShareDelta
          : sectorShareDelta // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      priceDelta: null == priceDelta
          ? _value._priceDelta
          : priceDelta // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ));
  }
}

/// @nodoc

class _$MarketSnapshotImpl extends _MarketSnapshot {
  const _$MarketSnapshotImpl(
      {required this.timestamp,
      required this.timeFrame,
      required final List<Trade> topTrades,
      required final List<Volume> topVolumes,
      required final List<Surge> surges,
      required final List<Volume> sectorVolumes,
      required final Map<String, double> volChangePct,
      required final Map<String, double> sectorShareDelta,
      required final Map<String, double> priceDelta})
      : _topTrades = topTrades,
        _topVolumes = topVolumes,
        _surges = surges,
        _sectorVolumes = sectorVolumes,
        _volChangePct = volChangePct,
        _sectorShareDelta = sectorShareDelta,
        _priceDelta = priceDelta,
        super._();

  @override
  final DateTime timestamp;
  @override
  final String timeFrame;
  final List<Trade> _topTrades;
  @override
  List<Trade> get topTrades {
    if (_topTrades is EqualUnmodifiableListView) return _topTrades;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topTrades);
  }

// ≥20M, 최근 50건
  final List<Volume> _topVolumes;
// ≥20M, 최근 50건
  @override
  List<Volume> get topVolumes {
    if (_topVolumes is EqualUnmodifiableListView) return _topVolumes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topVolumes);
  }

// 활성 마켓 상위 50개
  final List<Surge> _surges;
// 활성 마켓 상위 50개
  @override
  List<Surge> get surges {
    if (_surges is EqualUnmodifiableListView) return _surges;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_surges);
  }

// 변화 있는 코인만
  final List<Volume> _sectorVolumes;
// 변화 있는 코인만
  @override
  List<Volume> get sectorVolumes {
    if (_sectorVolumes is EqualUnmodifiableListView) return _sectorVolumes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sectorVolumes);
  }

// 주요 섹터 10개
  final Map<String, double> _volChangePct;
// 주요 섹터 10개
  @override
  Map<String, double> get volChangePct {
    if (_volChangePct is EqualUnmodifiableMapView) return _volChangePct;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_volChangePct);
  }

// 볼륨 변화율
  final Map<String, double> _sectorShareDelta;
// 볼륨 변화율
  @override
  Map<String, double> get sectorShareDelta {
    if (_sectorShareDelta is EqualUnmodifiableMapView) return _sectorShareDelta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_sectorShareDelta);
  }

// 섹터 점유율 변화 (수정됨)
  final Map<String, double> _priceDelta;
// 섹터 점유율 변화 (수정됨)
  @override
  Map<String, double> get priceDelta {
    if (_priceDelta is EqualUnmodifiableMapView) return _priceDelta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_priceDelta);
  }

  @override
  String toString() {
    return 'MarketSnapshot(timestamp: $timestamp, timeFrame: $timeFrame, topTrades: $topTrades, topVolumes: $topVolumes, surges: $surges, sectorVolumes: $sectorVolumes, volChangePct: $volChangePct, sectorShareDelta: $sectorShareDelta, priceDelta: $priceDelta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarketSnapshotImpl &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.timeFrame, timeFrame) ||
                other.timeFrame == timeFrame) &&
            const DeepCollectionEquality()
                .equals(other._topTrades, _topTrades) &&
            const DeepCollectionEquality()
                .equals(other._topVolumes, _topVolumes) &&
            const DeepCollectionEquality().equals(other._surges, _surges) &&
            const DeepCollectionEquality()
                .equals(other._sectorVolumes, _sectorVolumes) &&
            const DeepCollectionEquality()
                .equals(other._volChangePct, _volChangePct) &&
            const DeepCollectionEquality()
                .equals(other._sectorShareDelta, _sectorShareDelta) &&
            const DeepCollectionEquality()
                .equals(other._priceDelta, _priceDelta));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      timestamp,
      timeFrame,
      const DeepCollectionEquality().hash(_topTrades),
      const DeepCollectionEquality().hash(_topVolumes),
      const DeepCollectionEquality().hash(_surges),
      const DeepCollectionEquality().hash(_sectorVolumes),
      const DeepCollectionEquality().hash(_volChangePct),
      const DeepCollectionEquality().hash(_sectorShareDelta),
      const DeepCollectionEquality().hash(_priceDelta));

  /// Create a copy of MarketSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarketSnapshotImplCopyWith<_$MarketSnapshotImpl> get copyWith =>
      __$$MarketSnapshotImplCopyWithImpl<_$MarketSnapshotImpl>(
          this, _$identity);
}

abstract class _MarketSnapshot extends MarketSnapshot {
  const factory _MarketSnapshot(
      {required final DateTime timestamp,
      required final String timeFrame,
      required final List<Trade> topTrades,
      required final List<Volume> topVolumes,
      required final List<Surge> surges,
      required final List<Volume> sectorVolumes,
      required final Map<String, double> volChangePct,
      required final Map<String, double> sectorShareDelta,
      required final Map<String, double> priceDelta}) = _$MarketSnapshotImpl;
  const _MarketSnapshot._() : super._();

  @override
  DateTime get timestamp;
  @override
  String get timeFrame;
  @override
  List<Trade> get topTrades; // ≥20M, 최근 50건
  @override
  List<Volume> get topVolumes; // 활성 마켓 상위 50개
  @override
  List<Surge> get surges; // 변화 있는 코인만
  @override
  List<Volume> get sectorVolumes; // 주요 섹터 10개
  @override
  Map<String, double> get volChangePct; // 볼륨 변화율
  @override
  Map<String, double> get sectorShareDelta; // 섹터 점유율 변화 (수정됨)
  @override
  Map<String, double> get priceDelta;

  /// Create a copy of MarketSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarketSnapshotImplCopyWith<_$MarketSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CandidateInsight {
  String get id => throw _privateConstructorUsedError;
  String get template => throw _privateConstructorUsedError;
  double get score => throw _privateConstructorUsedError;
  double get weight => throw _privateConstructorUsedError;
  Map<String, dynamic> get templateVars => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isUrgent => throw _privateConstructorUsedError;

  /// Create a copy of CandidateInsight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CandidateInsightCopyWith<CandidateInsight> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CandidateInsightCopyWith<$Res> {
  factory $CandidateInsightCopyWith(
          CandidateInsight value, $Res Function(CandidateInsight) then) =
      _$CandidateInsightCopyWithImpl<$Res, CandidateInsight>;
  @useResult
  $Res call(
      {String id,
      String template,
      double score,
      double weight,
      Map<String, dynamic> templateVars,
      DateTime timestamp,
      bool isUrgent});
}

/// @nodoc
class _$CandidateInsightCopyWithImpl<$Res, $Val extends CandidateInsight>
    implements $CandidateInsightCopyWith<$Res> {
  _$CandidateInsightCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CandidateInsight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? template = null,
    Object? score = null,
    Object? weight = null,
    Object? templateVars = null,
    Object? timestamp = null,
    Object? isUrgent = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      template: null == template
          ? _value.template
          : template // ignore: cast_nullable_to_non_nullable
              as String,
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double,
      weight: null == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as double,
      templateVars: null == templateVars
          ? _value.templateVars
          : templateVars // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isUrgent: null == isUrgent
          ? _value.isUrgent
          : isUrgent // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CandidateInsightImplCopyWith<$Res>
    implements $CandidateInsightCopyWith<$Res> {
  factory _$$CandidateInsightImplCopyWith(_$CandidateInsightImpl value,
          $Res Function(_$CandidateInsightImpl) then) =
      __$$CandidateInsightImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String template,
      double score,
      double weight,
      Map<String, dynamic> templateVars,
      DateTime timestamp,
      bool isUrgent});
}

/// @nodoc
class __$$CandidateInsightImplCopyWithImpl<$Res>
    extends _$CandidateInsightCopyWithImpl<$Res, _$CandidateInsightImpl>
    implements _$$CandidateInsightImplCopyWith<$Res> {
  __$$CandidateInsightImplCopyWithImpl(_$CandidateInsightImpl _value,
      $Res Function(_$CandidateInsightImpl) _then)
      : super(_value, _then);

  /// Create a copy of CandidateInsight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? template = null,
    Object? score = null,
    Object? weight = null,
    Object? templateVars = null,
    Object? timestamp = null,
    Object? isUrgent = null,
  }) {
    return _then(_$CandidateInsightImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      template: null == template
          ? _value.template
          : template // ignore: cast_nullable_to_non_nullable
              as String,
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double,
      weight: null == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as double,
      templateVars: null == templateVars
          ? _value._templateVars
          : templateVars // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isUrgent: null == isUrgent
          ? _value.isUrgent
          : isUrgent // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$CandidateInsightImpl extends _CandidateInsight {
  const _$CandidateInsightImpl(
      {required this.id,
      required this.template,
      required this.score,
      required this.weight,
      required final Map<String, dynamic> templateVars,
      required this.timestamp,
      this.isUrgent = false})
      : _templateVars = templateVars,
        super._();

  @override
  final String id;
  @override
  final String template;
  @override
  final double score;
  @override
  final double weight;
  final Map<String, dynamic> _templateVars;
  @override
  Map<String, dynamic> get templateVars {
    if (_templateVars is EqualUnmodifiableMapView) return _templateVars;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_templateVars);
  }

  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final bool isUrgent;

  @override
  String toString() {
    return 'CandidateInsight(id: $id, template: $template, score: $score, weight: $weight, templateVars: $templateVars, timestamp: $timestamp, isUrgent: $isUrgent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CandidateInsightImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.template, template) ||
                other.template == template) &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            const DeepCollectionEquality()
                .equals(other._templateVars, _templateVars) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isUrgent, isUrgent) ||
                other.isUrgent == isUrgent));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, template, score, weight,
      const DeepCollectionEquality().hash(_templateVars), timestamp, isUrgent);

  /// Create a copy of CandidateInsight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CandidateInsightImplCopyWith<_$CandidateInsightImpl> get copyWith =>
      __$$CandidateInsightImplCopyWithImpl<_$CandidateInsightImpl>(
          this, _$identity);
}

abstract class _CandidateInsight extends CandidateInsight {
  const factory _CandidateInsight(
      {required final String id,
      required final String template,
      required final double score,
      required final double weight,
      required final Map<String, dynamic> templateVars,
      required final DateTime timestamp,
      final bool isUrgent}) = _$CandidateInsightImpl;
  const _CandidateInsight._() : super._();

  @override
  String get id;
  @override
  String get template;
  @override
  double get score;
  @override
  double get weight;
  @override
  Map<String, dynamic> get templateVars;
  @override
  DateTime get timestamp;
  @override
  bool get isUrgent;

  /// Create a copy of CandidateInsight
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CandidateInsightImplCopyWith<_$CandidateInsightImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BottomLineItem {
  String get headline => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  double get priority => throw _privateConstructorUsedError;
  String get sourceInsightId => throw _privateConstructorUsedError;
  bool get isUrgent => throw _privateConstructorUsedError;
  int get displayDurationSeconds => throw _privateConstructorUsedError;

  /// Create a copy of BottomLineItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BottomLineItemCopyWith<BottomLineItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BottomLineItemCopyWith<$Res> {
  factory $BottomLineItemCopyWith(
          BottomLineItem value, $Res Function(BottomLineItem) then) =
      _$BottomLineItemCopyWithImpl<$Res, BottomLineItem>;
  @useResult
  $Res call(
      {String headline,
      DateTime timestamp,
      double priority,
      String sourceInsightId,
      bool isUrgent,
      int displayDurationSeconds});
}

/// @nodoc
class _$BottomLineItemCopyWithImpl<$Res, $Val extends BottomLineItem>
    implements $BottomLineItemCopyWith<$Res> {
  _$BottomLineItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BottomLineItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? headline = null,
    Object? timestamp = null,
    Object? priority = null,
    Object? sourceInsightId = null,
    Object? isUrgent = null,
    Object? displayDurationSeconds = null,
  }) {
    return _then(_value.copyWith(
      headline: null == headline
          ? _value.headline
          : headline // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as double,
      sourceInsightId: null == sourceInsightId
          ? _value.sourceInsightId
          : sourceInsightId // ignore: cast_nullable_to_non_nullable
              as String,
      isUrgent: null == isUrgent
          ? _value.isUrgent
          : isUrgent // ignore: cast_nullable_to_non_nullable
              as bool,
      displayDurationSeconds: null == displayDurationSeconds
          ? _value.displayDurationSeconds
          : displayDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BottomLineItemImplCopyWith<$Res>
    implements $BottomLineItemCopyWith<$Res> {
  factory _$$BottomLineItemImplCopyWith(_$BottomLineItemImpl value,
          $Res Function(_$BottomLineItemImpl) then) =
      __$$BottomLineItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String headline,
      DateTime timestamp,
      double priority,
      String sourceInsightId,
      bool isUrgent,
      int displayDurationSeconds});
}

/// @nodoc
class __$$BottomLineItemImplCopyWithImpl<$Res>
    extends _$BottomLineItemCopyWithImpl<$Res, _$BottomLineItemImpl>
    implements _$$BottomLineItemImplCopyWith<$Res> {
  __$$BottomLineItemImplCopyWithImpl(
      _$BottomLineItemImpl _value, $Res Function(_$BottomLineItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of BottomLineItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? headline = null,
    Object? timestamp = null,
    Object? priority = null,
    Object? sourceInsightId = null,
    Object? isUrgent = null,
    Object? displayDurationSeconds = null,
  }) {
    return _then(_$BottomLineItemImpl(
      headline: null == headline
          ? _value.headline
          : headline // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as double,
      sourceInsightId: null == sourceInsightId
          ? _value.sourceInsightId
          : sourceInsightId // ignore: cast_nullable_to_non_nullable
              as String,
      isUrgent: null == isUrgent
          ? _value.isUrgent
          : isUrgent // ignore: cast_nullable_to_non_nullable
              as bool,
      displayDurationSeconds: null == displayDurationSeconds
          ? _value.displayDurationSeconds
          : displayDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$BottomLineItemImpl extends _BottomLineItem {
  const _$BottomLineItemImpl(
      {required this.headline,
      required this.timestamp,
      required this.priority,
      required this.sourceInsightId,
      this.isUrgent = false,
      this.displayDurationSeconds = 18})
      : super._();

  @override
  final String headline;
  @override
  final DateTime timestamp;
  @override
  final double priority;
  @override
  final String sourceInsightId;
  @override
  @JsonKey()
  final bool isUrgent;
  @override
  @JsonKey()
  final int displayDurationSeconds;

  @override
  String toString() {
    return 'BottomLineItem(headline: $headline, timestamp: $timestamp, priority: $priority, sourceInsightId: $sourceInsightId, isUrgent: $isUrgent, displayDurationSeconds: $displayDurationSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BottomLineItemImpl &&
            (identical(other.headline, headline) ||
                other.headline == headline) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.sourceInsightId, sourceInsightId) ||
                other.sourceInsightId == sourceInsightId) &&
            (identical(other.isUrgent, isUrgent) ||
                other.isUrgent == isUrgent) &&
            (identical(other.displayDurationSeconds, displayDurationSeconds) ||
                other.displayDurationSeconds == displayDurationSeconds));
  }

  @override
  int get hashCode => Object.hash(runtimeType, headline, timestamp, priority,
      sourceInsightId, isUrgent, displayDurationSeconds);

  /// Create a copy of BottomLineItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BottomLineItemImplCopyWith<_$BottomLineItemImpl> get copyWith =>
      __$$BottomLineItemImplCopyWithImpl<_$BottomLineItemImpl>(
          this, _$identity);
}

abstract class _BottomLineItem extends BottomLineItem {
  const factory _BottomLineItem(
      {required final String headline,
      required final DateTime timestamp,
      required final double priority,
      required final String sourceInsightId,
      final bool isUrgent,
      final int displayDurationSeconds}) = _$BottomLineItemImpl;
  const _BottomLineItem._() : super._();

  @override
  String get headline;
  @override
  DateTime get timestamp;
  @override
  double get priority;
  @override
  String get sourceInsightId;
  @override
  bool get isUrgent;
  @override
  int get displayDurationSeconds;

  /// Create a copy of BottomLineItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BottomLineItemImplCopyWith<_$BottomLineItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
