// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DownloadProgress {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadProgress);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DownloadProgress()';
}


}

/// @nodoc
class $DownloadProgressCopyWith<$Res>  {
$DownloadProgressCopyWith(DownloadProgress _, $Res Function(DownloadProgress) __);
}


/// Adds pattern-matching-related methods to [DownloadProgress].
extension DownloadProgressPatterns on DownloadProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DownloadProgress_Downloading value)?  downloading,TResult Function( DownloadProgress_Verifying value)?  verifying,TResult Function( DownloadProgress_Done value)?  done,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DownloadProgress_Downloading() when downloading != null:
return downloading(_that);case DownloadProgress_Verifying() when verifying != null:
return verifying(_that);case DownloadProgress_Done() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DownloadProgress_Downloading value)  downloading,required TResult Function( DownloadProgress_Verifying value)  verifying,required TResult Function( DownloadProgress_Done value)  done,}){
final _that = this;
switch (_that) {
case DownloadProgress_Downloading():
return downloading(_that);case DownloadProgress_Verifying():
return verifying(_that);case DownloadProgress_Done():
return done(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DownloadProgress_Downloading value)?  downloading,TResult? Function( DownloadProgress_Verifying value)?  verifying,TResult? Function( DownloadProgress_Done value)?  done,}){
final _that = this;
switch (_that) {
case DownloadProgress_Downloading() when downloading != null:
return downloading(_that);case DownloadProgress_Verifying() when verifying != null:
return verifying(_that);case DownloadProgress_Done() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BigInt received,  BigInt total)?  downloading,TResult Function()?  verifying,TResult Function( String path,  String sha256)?  done,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DownloadProgress_Downloading() when downloading != null:
return downloading(_that.received,_that.total);case DownloadProgress_Verifying() when verifying != null:
return verifying();case DownloadProgress_Done() when done != null:
return done(_that.path,_that.sha256);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BigInt received,  BigInt total)  downloading,required TResult Function()  verifying,required TResult Function( String path,  String sha256)  done,}) {final _that = this;
switch (_that) {
case DownloadProgress_Downloading():
return downloading(_that.received,_that.total);case DownloadProgress_Verifying():
return verifying();case DownloadProgress_Done():
return done(_that.path,_that.sha256);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BigInt received,  BigInt total)?  downloading,TResult? Function()?  verifying,TResult? Function( String path,  String sha256)?  done,}) {final _that = this;
switch (_that) {
case DownloadProgress_Downloading() when downloading != null:
return downloading(_that.received,_that.total);case DownloadProgress_Verifying() when verifying != null:
return verifying();case DownloadProgress_Done() when done != null:
return done(_that.path,_that.sha256);case _:
  return null;

}
}

}

/// @nodoc


class DownloadProgress_Downloading extends DownloadProgress {
  const DownloadProgress_Downloading({required this.received, required this.total}): super._();
  

 final  BigInt received;
 final  BigInt total;

/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadProgress_DownloadingCopyWith<DownloadProgress_Downloading> get copyWith => _$DownloadProgress_DownloadingCopyWithImpl<DownloadProgress_Downloading>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadProgress_Downloading&&(identical(other.received, received) || other.received == received)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode {
    return Object.hash(runtimeType,received,total);
}

@override
String toString() {
    return 'DownloadProgress.downloading(received: $received, total: $total)';
}


}

/// @nodoc
abstract mixin class $DownloadProgress_DownloadingCopyWith<$Res> implements $DownloadProgressCopyWith<$Res> {
  factory $DownloadProgress_DownloadingCopyWith(DownloadProgress_Downloading value, $Res Function(DownloadProgress_Downloading) _then) = _$DownloadProgress_DownloadingCopyWithImpl;
@useResult
$Res call({
 BigInt received, BigInt total
});




}
/// @nodoc
class _$DownloadProgress_DownloadingCopyWithImpl<$Res>
    implements $DownloadProgress_DownloadingCopyWith<$Res> {
  _$DownloadProgress_DownloadingCopyWithImpl(this._self, this._then);

  final DownloadProgress_Downloading _self;
  final $Res Function(DownloadProgress_Downloading) _then;

/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? received = null,Object? total = null,}) {
  return _then(DownloadProgress_Downloading(
received: null == received ? _self.received : received // ignore: cast_nullable_to_non_nullable
as BigInt,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class DownloadProgress_Verifying extends DownloadProgress {
  const DownloadProgress_Verifying(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadProgress_Verifying);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DownloadProgress.verifying()';
}


}




/// @nodoc


class DownloadProgress_Done extends DownloadProgress {
  const DownloadProgress_Done({required this.path, required this.sha256}): super._();
  

 final  String path;
 final  String sha256;

/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadProgress_DoneCopyWith<DownloadProgress_Done> get copyWith => _$DownloadProgress_DoneCopyWithImpl<DownloadProgress_Done>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadProgress_Done&&(identical(other.path, path) || other.path == path)&&(identical(other.sha256, sha256) || other.sha256 == sha256));
}


@override
int get hashCode {
    return Object.hash(runtimeType,path,sha256);
}

@override
String toString() {
    return 'DownloadProgress.done(path: $path, sha256: $sha256)';
}


}

/// @nodoc
abstract mixin class $DownloadProgress_DoneCopyWith<$Res> implements $DownloadProgressCopyWith<$Res> {
  factory $DownloadProgress_DoneCopyWith(DownloadProgress_Done value, $Res Function(DownloadProgress_Done) _then) = _$DownloadProgress_DoneCopyWithImpl;
@useResult
$Res call({
 String path, String sha256
});




}
/// @nodoc
class _$DownloadProgress_DoneCopyWithImpl<$Res>
    implements $DownloadProgress_DoneCopyWith<$Res> {
  _$DownloadProgress_DoneCopyWithImpl(this._self, this._then);

  final DownloadProgress_Done _self;
  final $Res Function(DownloadProgress_Done) _then;

/// Create a copy of DownloadProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? sha256 = null,}) {
  return _then(DownloadProgress_Done(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
