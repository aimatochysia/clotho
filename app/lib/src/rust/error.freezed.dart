// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoreError {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreError()';
}


}

/// @nodoc
class $CoreErrorCopyWith<$Res>  {
$CoreErrorCopyWith(CoreError _, $Res Function(CoreError) __);
}


/// Adds pattern-matching-related methods to [CoreError].
extension CoreErrorPatterns on CoreError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CoreError_NotARepository value)?  notARepository,TResult Function( CoreError_PathNotFound value)?  pathNotFound,TResult Function( CoreError_Git value)?  git,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that);case CoreError_Git() when git != null:
return git(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CoreError_NotARepository value)  notARepository,required TResult Function( CoreError_PathNotFound value)  pathNotFound,required TResult Function( CoreError_Git value)  git,}){
final _that = this;
switch (_that) {
case CoreError_NotARepository():
return notARepository(_that);case CoreError_PathNotFound():
return pathNotFound(_that);case CoreError_Git():
return git(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CoreError_NotARepository value)?  notARepository,TResult? Function( CoreError_PathNotFound value)?  pathNotFound,TResult? Function( CoreError_Git value)?  git,}){
final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that);case CoreError_Git() when git != null:
return git(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String path)?  notARepository,TResult Function( String path)?  pathNotFound,TResult Function( String message)?  git,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that.path);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that.path);case CoreError_Git() when git != null:
return git(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String path)  notARepository,required TResult Function( String path)  pathNotFound,required TResult Function( String message)  git,}) {final _that = this;
switch (_that) {
case CoreError_NotARepository():
return notARepository(_that.path);case CoreError_PathNotFound():
return pathNotFound(_that.path);case CoreError_Git():
return git(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String path)?  notARepository,TResult? Function( String path)?  pathNotFound,TResult? Function( String message)?  git,}) {final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that.path);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that.path);case CoreError_Git() when git != null:
return git(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class CoreError_NotARepository extends CoreError {
  const CoreError_NotARepository({required this.path}): super._();
  

 final  String path;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_NotARepositoryCopyWith<CoreError_NotARepository> get copyWith => _$CoreError_NotARepositoryCopyWithImpl<CoreError_NotARepository>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_NotARepository&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode {
    return Object.hash(runtimeType,path);
}

@override
String toString() {
    return 'CoreError.notARepository(path: $path)';
}


}

/// @nodoc
abstract mixin class $CoreError_NotARepositoryCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_NotARepositoryCopyWith(CoreError_NotARepository value, $Res Function(CoreError_NotARepository) _then) = _$CoreError_NotARepositoryCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$CoreError_NotARepositoryCopyWithImpl<$Res>
    implements $CoreError_NotARepositoryCopyWith<$Res> {
  _$CoreError_NotARepositoryCopyWithImpl(this._self, this._then);

  final CoreError_NotARepository _self;
  final $Res Function(CoreError_NotARepository) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(CoreError_NotARepository(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_PathNotFound extends CoreError {
  const CoreError_PathNotFound({required this.path}): super._();
  

 final  String path;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_PathNotFoundCopyWith<CoreError_PathNotFound> get copyWith => _$CoreError_PathNotFoundCopyWithImpl<CoreError_PathNotFound>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_PathNotFound&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode {
    return Object.hash(runtimeType,path);
}

@override
String toString() {
    return 'CoreError.pathNotFound(path: $path)';
}


}

/// @nodoc
abstract mixin class $CoreError_PathNotFoundCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_PathNotFoundCopyWith(CoreError_PathNotFound value, $Res Function(CoreError_PathNotFound) _then) = _$CoreError_PathNotFoundCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$CoreError_PathNotFoundCopyWithImpl<$Res>
    implements $CoreError_PathNotFoundCopyWith<$Res> {
  _$CoreError_PathNotFoundCopyWithImpl(this._self, this._then);

  final CoreError_PathNotFound _self;
  final $Res Function(CoreError_PathNotFound) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(CoreError_PathNotFound(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_Git extends CoreError {
  const CoreError_Git({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_GitCopyWith<CoreError_Git> get copyWith => _$CoreError_GitCopyWithImpl<CoreError_Git>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Git&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.git(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_GitCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_GitCopyWith(CoreError_Git value, $Res Function(CoreError_Git) _then) = _$CoreError_GitCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_GitCopyWithImpl<$Res>
    implements $CoreError_GitCopyWith<$Res> {
  _$CoreError_GitCopyWithImpl(this._self, this._then);

  final CoreError_Git _self;
  final $Res Function(CoreError_Git) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_Git(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
