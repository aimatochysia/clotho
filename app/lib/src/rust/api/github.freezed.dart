// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CloneProgress {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CloneProgress);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CloneProgress()';
}


}

/// @nodoc
class $CloneProgressCopyWith<$Res>  {
$CloneProgressCopyWith(CloneProgress _, $Res Function(CloneProgress) __);
}


/// Adds pattern-matching-related methods to [CloneProgress].
extension CloneProgressPatterns on CloneProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CloneProgress_Receiving value)?  receiving,TResult Function( CloneProgress_Resolving value)?  resolving,TResult Function( CloneProgress_CheckingOut value)?  checkingOut,TResult Function( CloneProgress_Done value)?  done,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CloneProgress_Receiving() when receiving != null:
return receiving(_that);case CloneProgress_Resolving() when resolving != null:
return resolving(_that);case CloneProgress_CheckingOut() when checkingOut != null:
return checkingOut(_that);case CloneProgress_Done() when done != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CloneProgress_Receiving value)  receiving,required TResult Function( CloneProgress_Resolving value)  resolving,required TResult Function( CloneProgress_CheckingOut value)  checkingOut,required TResult Function( CloneProgress_Done value)  done,}){
final _that = this;
switch (_that) {
case CloneProgress_Receiving():
return receiving(_that);case CloneProgress_Resolving():
return resolving(_that);case CloneProgress_CheckingOut():
return checkingOut(_that);case CloneProgress_Done():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CloneProgress_Receiving value)?  receiving,TResult? Function( CloneProgress_Resolving value)?  resolving,TResult? Function( CloneProgress_CheckingOut value)?  checkingOut,TResult? Function( CloneProgress_Done value)?  done,}){
final _that = this;
switch (_that) {
case CloneProgress_Receiving() when receiving != null:
return receiving(_that);case CloneProgress_Resolving() when resolving != null:
return resolving(_that);case CloneProgress_CheckingOut() when checkingOut != null:
return checkingOut(_that);case CloneProgress_Done() when done != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int receivedObjects,  int totalObjects,  BigInt receivedBytes)?  receiving,TResult Function( int indexedDeltas,  int totalDeltas)?  resolving,TResult Function( int done,  int total)?  checkingOut,TResult Function( String path)?  done,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CloneProgress_Receiving() when receiving != null:
return receiving(_that.receivedObjects,_that.totalObjects,_that.receivedBytes);case CloneProgress_Resolving() when resolving != null:
return resolving(_that.indexedDeltas,_that.totalDeltas);case CloneProgress_CheckingOut() when checkingOut != null:
return checkingOut(_that.done,_that.total);case CloneProgress_Done() when done != null:
return done(_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int receivedObjects,  int totalObjects,  BigInt receivedBytes)  receiving,required TResult Function( int indexedDeltas,  int totalDeltas)  resolving,required TResult Function( int done,  int total)  checkingOut,required TResult Function( String path)  done,}) {final _that = this;
switch (_that) {
case CloneProgress_Receiving():
return receiving(_that.receivedObjects,_that.totalObjects,_that.receivedBytes);case CloneProgress_Resolving():
return resolving(_that.indexedDeltas,_that.totalDeltas);case CloneProgress_CheckingOut():
return checkingOut(_that.done,_that.total);case CloneProgress_Done():
return done(_that.path);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int receivedObjects,  int totalObjects,  BigInt receivedBytes)?  receiving,TResult? Function( int indexedDeltas,  int totalDeltas)?  resolving,TResult? Function( int done,  int total)?  checkingOut,TResult? Function( String path)?  done,}) {final _that = this;
switch (_that) {
case CloneProgress_Receiving() when receiving != null:
return receiving(_that.receivedObjects,_that.totalObjects,_that.receivedBytes);case CloneProgress_Resolving() when resolving != null:
return resolving(_that.indexedDeltas,_that.totalDeltas);case CloneProgress_CheckingOut() when checkingOut != null:
return checkingOut(_that.done,_that.total);case CloneProgress_Done() when done != null:
return done(_that.path);case _:
  return null;

}
}

}

/// @nodoc


class CloneProgress_Receiving extends CloneProgress {
  const CloneProgress_Receiving({required this.receivedObjects, required this.totalObjects, required this.receivedBytes}): super._();
  

 final  int receivedObjects;
 final  int totalObjects;
 final  BigInt receivedBytes;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CloneProgress_ReceivingCopyWith<CloneProgress_Receiving> get copyWith => _$CloneProgress_ReceivingCopyWithImpl<CloneProgress_Receiving>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CloneProgress_Receiving&&(identical(other.receivedObjects, receivedObjects) || other.receivedObjects == receivedObjects)&&(identical(other.totalObjects, totalObjects) || other.totalObjects == totalObjects)&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,receivedObjects,totalObjects,receivedBytes);
}

@override
String toString() {
    return 'CloneProgress.receiving(receivedObjects: $receivedObjects, totalObjects: $totalObjects, receivedBytes: $receivedBytes)';
}


}

/// @nodoc
abstract mixin class $CloneProgress_ReceivingCopyWith<$Res> implements $CloneProgressCopyWith<$Res> {
  factory $CloneProgress_ReceivingCopyWith(CloneProgress_Receiving value, $Res Function(CloneProgress_Receiving) _then) = _$CloneProgress_ReceivingCopyWithImpl;
@useResult
$Res call({
 int receivedObjects, int totalObjects, BigInt receivedBytes
});




}
/// @nodoc
class _$CloneProgress_ReceivingCopyWithImpl<$Res>
    implements $CloneProgress_ReceivingCopyWith<$Res> {
  _$CloneProgress_ReceivingCopyWithImpl(this._self, this._then);

  final CloneProgress_Receiving _self;
  final $Res Function(CloneProgress_Receiving) _then;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? receivedObjects = null,Object? totalObjects = null,Object? receivedBytes = null,}) {
  return _then(CloneProgress_Receiving(
receivedObjects: null == receivedObjects ? _self.receivedObjects : receivedObjects // ignore: cast_nullable_to_non_nullable
as int,totalObjects: null == totalObjects ? _self.totalObjects : totalObjects // ignore: cast_nullable_to_non_nullable
as int,receivedBytes: null == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class CloneProgress_Resolving extends CloneProgress {
  const CloneProgress_Resolving({required this.indexedDeltas, required this.totalDeltas}): super._();
  

 final  int indexedDeltas;
 final  int totalDeltas;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CloneProgress_ResolvingCopyWith<CloneProgress_Resolving> get copyWith => _$CloneProgress_ResolvingCopyWithImpl<CloneProgress_Resolving>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CloneProgress_Resolving&&(identical(other.indexedDeltas, indexedDeltas) || other.indexedDeltas == indexedDeltas)&&(identical(other.totalDeltas, totalDeltas) || other.totalDeltas == totalDeltas));
}


@override
int get hashCode {
    return Object.hash(runtimeType,indexedDeltas,totalDeltas);
}

@override
String toString() {
    return 'CloneProgress.resolving(indexedDeltas: $indexedDeltas, totalDeltas: $totalDeltas)';
}


}

/// @nodoc
abstract mixin class $CloneProgress_ResolvingCopyWith<$Res> implements $CloneProgressCopyWith<$Res> {
  factory $CloneProgress_ResolvingCopyWith(CloneProgress_Resolving value, $Res Function(CloneProgress_Resolving) _then) = _$CloneProgress_ResolvingCopyWithImpl;
@useResult
$Res call({
 int indexedDeltas, int totalDeltas
});




}
/// @nodoc
class _$CloneProgress_ResolvingCopyWithImpl<$Res>
    implements $CloneProgress_ResolvingCopyWith<$Res> {
  _$CloneProgress_ResolvingCopyWithImpl(this._self, this._then);

  final CloneProgress_Resolving _self;
  final $Res Function(CloneProgress_Resolving) _then;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? indexedDeltas = null,Object? totalDeltas = null,}) {
  return _then(CloneProgress_Resolving(
indexedDeltas: null == indexedDeltas ? _self.indexedDeltas : indexedDeltas // ignore: cast_nullable_to_non_nullable
as int,totalDeltas: null == totalDeltas ? _self.totalDeltas : totalDeltas // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class CloneProgress_CheckingOut extends CloneProgress {
  const CloneProgress_CheckingOut({required this.done, required this.total}): super._();
  

 final  int done;
 final  int total;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CloneProgress_CheckingOutCopyWith<CloneProgress_CheckingOut> get copyWith => _$CloneProgress_CheckingOutCopyWithImpl<CloneProgress_CheckingOut>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CloneProgress_CheckingOut&&(identical(other.done, done) || other.done == done)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode {
    return Object.hash(runtimeType,done,total);
}

@override
String toString() {
    return 'CloneProgress.checkingOut(done: $done, total: $total)';
}


}

/// @nodoc
abstract mixin class $CloneProgress_CheckingOutCopyWith<$Res> implements $CloneProgressCopyWith<$Res> {
  factory $CloneProgress_CheckingOutCopyWith(CloneProgress_CheckingOut value, $Res Function(CloneProgress_CheckingOut) _then) = _$CloneProgress_CheckingOutCopyWithImpl;
@useResult
$Res call({
 int done, int total
});




}
/// @nodoc
class _$CloneProgress_CheckingOutCopyWithImpl<$Res>
    implements $CloneProgress_CheckingOutCopyWith<$Res> {
  _$CloneProgress_CheckingOutCopyWithImpl(this._self, this._then);

  final CloneProgress_CheckingOut _self;
  final $Res Function(CloneProgress_CheckingOut) _then;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? done = null,Object? total = null,}) {
  return _then(CloneProgress_CheckingOut(
done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class CloneProgress_Done extends CloneProgress {
  const CloneProgress_Done({required this.path}): super._();
  

 final  String path;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CloneProgress_DoneCopyWith<CloneProgress_Done> get copyWith => _$CloneProgress_DoneCopyWithImpl<CloneProgress_Done>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CloneProgress_Done&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode {
    return Object.hash(runtimeType,path);
}

@override
String toString() {
    return 'CloneProgress.done(path: $path)';
}


}

/// @nodoc
abstract mixin class $CloneProgress_DoneCopyWith<$Res> implements $CloneProgressCopyWith<$Res> {
  factory $CloneProgress_DoneCopyWith(CloneProgress_Done value, $Res Function(CloneProgress_Done) _then) = _$CloneProgress_DoneCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$CloneProgress_DoneCopyWithImpl<$Res>
    implements $CloneProgress_DoneCopyWith<$Res> {
  _$CloneProgress_DoneCopyWithImpl(this._self, this._then);

  final CloneProgress_Done _self;
  final $Res Function(CloneProgress_Done) _then;

/// Create a copy of CloneProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(CloneProgress_Done(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$DevicePoll {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DevicePoll);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DevicePoll()';
}


}

/// @nodoc
class $DevicePollCopyWith<$Res>  {
$DevicePollCopyWith(DevicePoll _, $Res Function(DevicePoll) __);
}


/// Adds pattern-matching-related methods to [DevicePoll].
extension DevicePollPatterns on DevicePoll {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DevicePoll_Pending value)?  pending,TResult Function( DevicePoll_SlowDown value)?  slowDown,TResult Function( DevicePoll_Authorized value)?  authorized,TResult Function( DevicePoll_Expired value)?  expired,TResult Function( DevicePoll_Denied value)?  denied,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DevicePoll_Pending() when pending != null:
return pending(_that);case DevicePoll_SlowDown() when slowDown != null:
return slowDown(_that);case DevicePoll_Authorized() when authorized != null:
return authorized(_that);case DevicePoll_Expired() when expired != null:
return expired(_that);case DevicePoll_Denied() when denied != null:
return denied(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DevicePoll_Pending value)  pending,required TResult Function( DevicePoll_SlowDown value)  slowDown,required TResult Function( DevicePoll_Authorized value)  authorized,required TResult Function( DevicePoll_Expired value)  expired,required TResult Function( DevicePoll_Denied value)  denied,}){
final _that = this;
switch (_that) {
case DevicePoll_Pending():
return pending(_that);case DevicePoll_SlowDown():
return slowDown(_that);case DevicePoll_Authorized():
return authorized(_that);case DevicePoll_Expired():
return expired(_that);case DevicePoll_Denied():
return denied(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DevicePoll_Pending value)?  pending,TResult? Function( DevicePoll_SlowDown value)?  slowDown,TResult? Function( DevicePoll_Authorized value)?  authorized,TResult? Function( DevicePoll_Expired value)?  expired,TResult? Function( DevicePoll_Denied value)?  denied,}){
final _that = this;
switch (_that) {
case DevicePoll_Pending() when pending != null:
return pending(_that);case DevicePoll_SlowDown() when slowDown != null:
return slowDown(_that);case DevicePoll_Authorized() when authorized != null:
return authorized(_that);case DevicePoll_Expired() when expired != null:
return expired(_that);case DevicePoll_Denied() when denied != null:
return denied(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  pending,TResult Function( int interval)?  slowDown,TResult Function( String token,  String scopes)?  authorized,TResult Function()?  expired,TResult Function()?  denied,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DevicePoll_Pending() when pending != null:
return pending();case DevicePoll_SlowDown() when slowDown != null:
return slowDown(_that.interval);case DevicePoll_Authorized() when authorized != null:
return authorized(_that.token,_that.scopes);case DevicePoll_Expired() when expired != null:
return expired();case DevicePoll_Denied() when denied != null:
return denied();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  pending,required TResult Function( int interval)  slowDown,required TResult Function( String token,  String scopes)  authorized,required TResult Function()  expired,required TResult Function()  denied,}) {final _that = this;
switch (_that) {
case DevicePoll_Pending():
return pending();case DevicePoll_SlowDown():
return slowDown(_that.interval);case DevicePoll_Authorized():
return authorized(_that.token,_that.scopes);case DevicePoll_Expired():
return expired();case DevicePoll_Denied():
return denied();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  pending,TResult? Function( int interval)?  slowDown,TResult? Function( String token,  String scopes)?  authorized,TResult? Function()?  expired,TResult? Function()?  denied,}) {final _that = this;
switch (_that) {
case DevicePoll_Pending() when pending != null:
return pending();case DevicePoll_SlowDown() when slowDown != null:
return slowDown(_that.interval);case DevicePoll_Authorized() when authorized != null:
return authorized(_that.token,_that.scopes);case DevicePoll_Expired() when expired != null:
return expired();case DevicePoll_Denied() when denied != null:
return denied();case _:
  return null;

}
}

}

/// @nodoc


class DevicePoll_Pending extends DevicePoll {
  const DevicePoll_Pending(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DevicePoll_Pending);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DevicePoll.pending()';
}


}




/// @nodoc


class DevicePoll_SlowDown extends DevicePoll {
  const DevicePoll_SlowDown({required this.interval}): super._();
  

 final  int interval;

/// Create a copy of DevicePoll
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DevicePoll_SlowDownCopyWith<DevicePoll_SlowDown> get copyWith => _$DevicePoll_SlowDownCopyWithImpl<DevicePoll_SlowDown>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DevicePoll_SlowDown&&(identical(other.interval, interval) || other.interval == interval));
}


@override
int get hashCode {
    return Object.hash(runtimeType,interval);
}

@override
String toString() {
    return 'DevicePoll.slowDown(interval: $interval)';
}


}

/// @nodoc
abstract mixin class $DevicePoll_SlowDownCopyWith<$Res> implements $DevicePollCopyWith<$Res> {
  factory $DevicePoll_SlowDownCopyWith(DevicePoll_SlowDown value, $Res Function(DevicePoll_SlowDown) _then) = _$DevicePoll_SlowDownCopyWithImpl;
@useResult
$Res call({
 int interval
});




}
/// @nodoc
class _$DevicePoll_SlowDownCopyWithImpl<$Res>
    implements $DevicePoll_SlowDownCopyWith<$Res> {
  _$DevicePoll_SlowDownCopyWithImpl(this._self, this._then);

  final DevicePoll_SlowDown _self;
  final $Res Function(DevicePoll_SlowDown) _then;

/// Create a copy of DevicePoll
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? interval = null,}) {
  return _then(DevicePoll_SlowDown(
interval: null == interval ? _self.interval : interval // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class DevicePoll_Authorized extends DevicePoll {
  const DevicePoll_Authorized({required this.token, required this.scopes}): super._();
  

 final  String token;
 final  String scopes;

/// Create a copy of DevicePoll
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DevicePoll_AuthorizedCopyWith<DevicePoll_Authorized> get copyWith => _$DevicePoll_AuthorizedCopyWithImpl<DevicePoll_Authorized>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DevicePoll_Authorized&&(identical(other.token, token) || other.token == token)&&(identical(other.scopes, scopes) || other.scopes == scopes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,token,scopes);
}

@override
String toString() {
    return 'DevicePoll.authorized(token: $token, scopes: $scopes)';
}


}

/// @nodoc
abstract mixin class $DevicePoll_AuthorizedCopyWith<$Res> implements $DevicePollCopyWith<$Res> {
  factory $DevicePoll_AuthorizedCopyWith(DevicePoll_Authorized value, $Res Function(DevicePoll_Authorized) _then) = _$DevicePoll_AuthorizedCopyWithImpl;
@useResult
$Res call({
 String token, String scopes
});




}
/// @nodoc
class _$DevicePoll_AuthorizedCopyWithImpl<$Res>
    implements $DevicePoll_AuthorizedCopyWith<$Res> {
  _$DevicePoll_AuthorizedCopyWithImpl(this._self, this._then);

  final DevicePoll_Authorized _self;
  final $Res Function(DevicePoll_Authorized) _then;

/// Create a copy of DevicePoll
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? scopes = null,}) {
  return _then(DevicePoll_Authorized(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,scopes: null == scopes ? _self.scopes : scopes // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class DevicePoll_Expired extends DevicePoll {
  const DevicePoll_Expired(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DevicePoll_Expired);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DevicePoll.expired()';
}


}




/// @nodoc


class DevicePoll_Denied extends DevicePoll {
  const DevicePoll_Denied(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DevicePoll_Denied);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DevicePoll.denied()';
}


}




// dart format on
