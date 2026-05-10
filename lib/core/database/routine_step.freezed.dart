// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'routine_step.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RoutineStep _$RoutineStepFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'check':
      return CheckStep.fromJson(json);
    case 'info':
      return InfoStep.fromJson(json);
    case 'timer':
      return TimerStep.fromJson(json);

    default:
      throw CheckedFromJsonException(
        json,
        'runtimeType',
        'RoutineStep',
        'Invalid union type "${json['runtimeType']}"!',
      );
  }
}

/// @nodoc
mixin _$RoutineStep {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )
    check,
    required TResult Function(String message) info,
    required TResult Function(int duration) timer,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult? Function(String message)? info,
    TResult? Function(int duration)? timer,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult Function(String message)? info,
    TResult Function(int duration)? timer,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStep value) check,
    required TResult Function(InfoStep value) info,
    required TResult Function(TimerStep value) timer,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStep value)? check,
    TResult? Function(InfoStep value)? info,
    TResult? Function(TimerStep value)? timer,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStep value)? check,
    TResult Function(InfoStep value)? info,
    TResult Function(TimerStep value)? timer,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Serializes this RoutineStep to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoutineStepCopyWith<$Res> {
  factory $RoutineStepCopyWith(
    RoutineStep value,
    $Res Function(RoutineStep) then,
  ) = _$RoutineStepCopyWithImpl<$Res, RoutineStep>;
}

/// @nodoc
class _$RoutineStepCopyWithImpl<$Res, $Val extends RoutineStep>
    implements $RoutineStepCopyWith<$Res> {
  _$RoutineStepCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$CheckStepImplCopyWith<$Res> {
  factory _$$CheckStepImplCopyWith(
    _$CheckStepImpl value,
    $Res Function(_$CheckStepImpl) then,
  ) = __$$CheckStepImplCopyWithImpl<$Res>;
  @useResult
  $Res call({
    String label,
    bool requiresPhoto,
    int photoCount,
    String? photoPrompt,
    bool allowSkip,
    bool allowGallery,
    StepGuidanceAudio? guidanceAudio,
  });
}

/// @nodoc
class __$$CheckStepImplCopyWithImpl<$Res>
    extends _$RoutineStepCopyWithImpl<$Res, _$CheckStepImpl>
    implements _$$CheckStepImplCopyWith<$Res> {
  __$$CheckStepImplCopyWithImpl(
    _$CheckStepImpl _value,
    $Res Function(_$CheckStepImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? requiresPhoto = null,
    Object? photoCount = null,
    Object? photoPrompt = freezed,
    Object? allowSkip = null,
    Object? allowGallery = null,
    Object? guidanceAudio = freezed,
  }) {
    return _then(
      _$CheckStepImpl(
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        requiresPhoto: null == requiresPhoto
            ? _value.requiresPhoto
            : requiresPhoto // ignore: cast_nullable_to_non_nullable
                  as bool,
        photoCount: null == photoCount
            ? _value.photoCount
            : photoCount // ignore: cast_nullable_to_non_nullable
                  as int,
        photoPrompt: freezed == photoPrompt
            ? _value.photoPrompt
            : photoPrompt // ignore: cast_nullable_to_non_nullable
                  as String?,
        allowSkip: null == allowSkip
            ? _value.allowSkip
            : allowSkip // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowGallery: null == allowGallery
            ? _value.allowGallery
            : allowGallery // ignore: cast_nullable_to_non_nullable
                  as bool,
        guidanceAudio: freezed == guidanceAudio
            ? _value.guidanceAudio
            : guidanceAudio // ignore: cast_nullable_to_non_nullable
                  as StepGuidanceAudio?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CheckStepImpl implements CheckStep {
  const _$CheckStepImpl({
    required this.label,
    this.requiresPhoto = false,
    this.photoCount = 1,
    this.photoPrompt,
    this.allowSkip = false,
    this.allowGallery = true,
    this.guidanceAudio,
    final String? $type,
  }) : $type = $type ?? 'check';

  factory _$CheckStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckStepImplFromJson(json);

  @override
  final String label;
  @override
  @JsonKey()
  final bool requiresPhoto;
  @override
  @JsonKey()
  final int photoCount;
  @override
  final String? photoPrompt;
  @override
  @JsonKey()
  final bool allowSkip;
  @override
  @JsonKey()
  final bool allowGallery;
  @override
  final StepGuidanceAudio? guidanceAudio;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'RoutineStep.check(label: $label, requiresPhoto: $requiresPhoto, photoCount: $photoCount, photoPrompt: $photoPrompt, allowSkip: $allowSkip, allowGallery: $allowGallery, guidanceAudio: $guidanceAudio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckStepImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.requiresPhoto, requiresPhoto) ||
                other.requiresPhoto == requiresPhoto) &&
            (identical(other.photoCount, photoCount) ||
                other.photoCount == photoCount) &&
            (identical(other.photoPrompt, photoPrompt) ||
                other.photoPrompt == photoPrompt) &&
            (identical(other.allowSkip, allowSkip) ||
                other.allowSkip == allowSkip) &&
            (identical(other.allowGallery, allowGallery) ||
                other.allowGallery == allowGallery) &&
            (identical(other.guidanceAudio, guidanceAudio) ||
                other.guidanceAudio == guidanceAudio));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    label,
    requiresPhoto,
    photoCount,
    photoPrompt,
    allowSkip,
    allowGallery,
    guidanceAudio,
  );

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckStepImplCopyWith<_$CheckStepImpl> get copyWith =>
      __$$CheckStepImplCopyWithImpl<_$CheckStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )
    check,
    required TResult Function(String message) info,
    required TResult Function(int duration) timer,
  }) {
    return check(
      label,
      requiresPhoto,
      photoCount,
      photoPrompt,
      allowSkip,
      allowGallery,
      guidanceAudio,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult? Function(String message)? info,
    TResult? Function(int duration)? timer,
  }) {
    return check?.call(
      label,
      requiresPhoto,
      photoCount,
      photoPrompt,
      allowSkip,
      allowGallery,
      guidanceAudio,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult Function(String message)? info,
    TResult Function(int duration)? timer,
    required TResult orElse(),
  }) {
    if (check != null) {
      return check(
        label,
        requiresPhoto,
        photoCount,
        photoPrompt,
        allowSkip,
        allowGallery,
        guidanceAudio,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStep value) check,
    required TResult Function(InfoStep value) info,
    required TResult Function(TimerStep value) timer,
  }) {
    return check(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStep value)? check,
    TResult? Function(InfoStep value)? info,
    TResult? Function(TimerStep value)? timer,
  }) {
    return check?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStep value)? check,
    TResult Function(InfoStep value)? info,
    TResult Function(TimerStep value)? timer,
    required TResult orElse(),
  }) {
    if (check != null) {
      return check(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckStepImplToJson(this);
  }
}

abstract class CheckStep implements RoutineStep {
  const factory CheckStep({
    required final String label,
    final bool requiresPhoto,
    final int photoCount,
    final String? photoPrompt,
    final bool allowSkip,
    final bool allowGallery,
    final StepGuidanceAudio? guidanceAudio,
  }) = _$CheckStepImpl;

  factory CheckStep.fromJson(Map<String, dynamic> json) =
      _$CheckStepImpl.fromJson;

  String get label;
  bool get requiresPhoto;
  int get photoCount;
  String? get photoPrompt;
  bool get allowSkip;
  bool get allowGallery;
  StepGuidanceAudio? get guidanceAudio;

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckStepImplCopyWith<_$CheckStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InfoStepImplCopyWith<$Res> {
  factory _$$InfoStepImplCopyWith(
    _$InfoStepImpl value,
    $Res Function(_$InfoStepImpl) then,
  ) = __$$InfoStepImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$InfoStepImplCopyWithImpl<$Res>
    extends _$RoutineStepCopyWithImpl<$Res, _$InfoStepImpl>
    implements _$$InfoStepImplCopyWith<$Res> {
  __$$InfoStepImplCopyWithImpl(
    _$InfoStepImpl _value,
    $Res Function(_$InfoStepImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$InfoStepImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$InfoStepImpl implements InfoStep {
  const _$InfoStepImpl({required this.message, final String? $type})
    : $type = $type ?? 'info';

  factory _$InfoStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$InfoStepImplFromJson(json);

  @override
  final String message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'RoutineStep.info(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InfoStepImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InfoStepImplCopyWith<_$InfoStepImpl> get copyWith =>
      __$$InfoStepImplCopyWithImpl<_$InfoStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )
    check,
    required TResult Function(String message) info,
    required TResult Function(int duration) timer,
  }) {
    return info(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult? Function(String message)? info,
    TResult? Function(int duration)? timer,
  }) {
    return info?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult Function(String message)? info,
    TResult Function(int duration)? timer,
    required TResult orElse(),
  }) {
    if (info != null) {
      return info(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStep value) check,
    required TResult Function(InfoStep value) info,
    required TResult Function(TimerStep value) timer,
  }) {
    return info(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStep value)? check,
    TResult? Function(InfoStep value)? info,
    TResult? Function(TimerStep value)? timer,
  }) {
    return info?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStep value)? check,
    TResult Function(InfoStep value)? info,
    TResult Function(TimerStep value)? timer,
    required TResult orElse(),
  }) {
    if (info != null) {
      return info(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$InfoStepImplToJson(this);
  }
}

abstract class InfoStep implements RoutineStep {
  const factory InfoStep({required final String message}) = _$InfoStepImpl;

  factory InfoStep.fromJson(Map<String, dynamic> json) =
      _$InfoStepImpl.fromJson;

  String get message;

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InfoStepImplCopyWith<_$InfoStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TimerStepImplCopyWith<$Res> {
  factory _$$TimerStepImplCopyWith(
    _$TimerStepImpl value,
    $Res Function(_$TimerStepImpl) then,
  ) = __$$TimerStepImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int duration});
}

/// @nodoc
class __$$TimerStepImplCopyWithImpl<$Res>
    extends _$RoutineStepCopyWithImpl<$Res, _$TimerStepImpl>
    implements _$$TimerStepImplCopyWith<$Res> {
  __$$TimerStepImplCopyWithImpl(
    _$TimerStepImpl _value,
    $Res Function(_$TimerStepImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? duration = null}) {
    return _then(
      _$TimerStepImpl(
        duration: null == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TimerStepImpl implements TimerStep {
  const _$TimerStepImpl({required this.duration, final String? $type})
    : $type = $type ?? 'timer';

  factory _$TimerStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimerStepImplFromJson(json);

  @override
  final int duration;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'RoutineStep.timer(duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimerStepImpl &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, duration);

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimerStepImplCopyWith<_$TimerStepImpl> get copyWith =>
      __$$TimerStepImplCopyWithImpl<_$TimerStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )
    check,
    required TResult Function(String message) info,
    required TResult Function(int duration) timer,
  }) {
    return timer(duration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult? Function(String message)? info,
    TResult? Function(int duration)? timer,
  }) {
    return timer?.call(duration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String label,
      bool requiresPhoto,
      int photoCount,
      String? photoPrompt,
      bool allowSkip,
      bool allowGallery,
      StepGuidanceAudio? guidanceAudio,
    )?
    check,
    TResult Function(String message)? info,
    TResult Function(int duration)? timer,
    required TResult orElse(),
  }) {
    if (timer != null) {
      return timer(duration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStep value) check,
    required TResult Function(InfoStep value) info,
    required TResult Function(TimerStep value) timer,
  }) {
    return timer(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStep value)? check,
    TResult? Function(InfoStep value)? info,
    TResult? Function(TimerStep value)? timer,
  }) {
    return timer?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStep value)? check,
    TResult Function(InfoStep value)? info,
    TResult Function(TimerStep value)? timer,
    required TResult orElse(),
  }) {
    if (timer != null) {
      return timer(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TimerStepImplToJson(this);
  }
}

abstract class TimerStep implements RoutineStep {
  const factory TimerStep({required final int duration}) = _$TimerStepImpl;

  factory TimerStep.fromJson(Map<String, dynamic> json) =
      _$TimerStepImpl.fromJson;

  int get duration;

  /// Create a copy of RoutineStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimerStepImplCopyWith<_$TimerStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
