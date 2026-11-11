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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CoreError_NotARepository value)?  notARepository,TResult Function( CoreError_PathNotFound value)?  pathNotFound,TResult Function( CoreError_NothingToCommit value)?  nothingToCommit,TResult Function( CoreError_MissingIdentity value)?  missingIdentity,TResult Function( CoreError_Conflicts value)?  conflicts,TResult Function( CoreError_NotFastForward value)?  notFastForward,TResult Function( CoreError_DirtyWorktree value)?  dirtyWorktree,TResult Function( CoreError_BranchNotMerged value)?  branchNotMerged,TResult Function( CoreError_NoUpstream value)?  noUpstream,TResult Function( CoreError_DetachedHead value)?  detachedHead,TResult Function( CoreError_Auth value)?  auth,TResult Function( CoreError_PushRejected value)?  pushRejected,TResult Function( CoreError_Network value)?  network,TResult Function( CoreError_GitHub value)?  gitHub,TResult Function( CoreError_Integrity value)?  integrity,TResult Function( CoreError_InvalidInput value)?  invalidInput,TResult Function( CoreError_Io value)?  io,TResult Function( CoreError_Git value)?  git,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that);case CoreError_NothingToCommit() when nothingToCommit != null:
return nothingToCommit(_that);case CoreError_MissingIdentity() when missingIdentity != null:
return missingIdentity(_that);case CoreError_Conflicts() when conflicts != null:
return conflicts(_that);case CoreError_NotFastForward() when notFastForward != null:
return notFastForward(_that);case CoreError_DirtyWorktree() when dirtyWorktree != null:
return dirtyWorktree(_that);case CoreError_BranchNotMerged() when branchNotMerged != null:
return branchNotMerged(_that);case CoreError_NoUpstream() when noUpstream != null:
return noUpstream(_that);case CoreError_DetachedHead() when detachedHead != null:
return detachedHead(_that);case CoreError_Auth() when auth != null:
return auth(_that);case CoreError_PushRejected() when pushRejected != null:
return pushRejected(_that);case CoreError_Network() when network != null:
return network(_that);case CoreError_GitHub() when gitHub != null:
return gitHub(_that);case CoreError_Integrity() when integrity != null:
return integrity(_that);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that);case CoreError_Io() when io != null:
return io(_that);case CoreError_Git() when git != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CoreError_NotARepository value)  notARepository,required TResult Function( CoreError_PathNotFound value)  pathNotFound,required TResult Function( CoreError_NothingToCommit value)  nothingToCommit,required TResult Function( CoreError_MissingIdentity value)  missingIdentity,required TResult Function( CoreError_Conflicts value)  conflicts,required TResult Function( CoreError_NotFastForward value)  notFastForward,required TResult Function( CoreError_DirtyWorktree value)  dirtyWorktree,required TResult Function( CoreError_BranchNotMerged value)  branchNotMerged,required TResult Function( CoreError_NoUpstream value)  noUpstream,required TResult Function( CoreError_DetachedHead value)  detachedHead,required TResult Function( CoreError_Auth value)  auth,required TResult Function( CoreError_PushRejected value)  pushRejected,required TResult Function( CoreError_Network value)  network,required TResult Function( CoreError_GitHub value)  gitHub,required TResult Function( CoreError_Integrity value)  integrity,required TResult Function( CoreError_InvalidInput value)  invalidInput,required TResult Function( CoreError_Io value)  io,required TResult Function( CoreError_Git value)  git,}){
final _that = this;
switch (_that) {
case CoreError_NotARepository():
return notARepository(_that);case CoreError_PathNotFound():
return pathNotFound(_that);case CoreError_NothingToCommit():
return nothingToCommit(_that);case CoreError_MissingIdentity():
return missingIdentity(_that);case CoreError_Conflicts():
return conflicts(_that);case CoreError_NotFastForward():
return notFastForward(_that);case CoreError_DirtyWorktree():
return dirtyWorktree(_that);case CoreError_BranchNotMerged():
return branchNotMerged(_that);case CoreError_NoUpstream():
return noUpstream(_that);case CoreError_DetachedHead():
return detachedHead(_that);case CoreError_Auth():
return auth(_that);case CoreError_PushRejected():
return pushRejected(_that);case CoreError_Network():
return network(_that);case CoreError_GitHub():
return gitHub(_that);case CoreError_Integrity():
return integrity(_that);case CoreError_InvalidInput():
return invalidInput(_that);case CoreError_Io():
return io(_that);case CoreError_Git():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CoreError_NotARepository value)?  notARepository,TResult? Function( CoreError_PathNotFound value)?  pathNotFound,TResult? Function( CoreError_NothingToCommit value)?  nothingToCommit,TResult? Function( CoreError_MissingIdentity value)?  missingIdentity,TResult? Function( CoreError_Conflicts value)?  conflicts,TResult? Function( CoreError_NotFastForward value)?  notFastForward,TResult? Function( CoreError_DirtyWorktree value)?  dirtyWorktree,TResult? Function( CoreError_BranchNotMerged value)?  branchNotMerged,TResult? Function( CoreError_NoUpstream value)?  noUpstream,TResult? Function( CoreError_DetachedHead value)?  detachedHead,TResult? Function( CoreError_Auth value)?  auth,TResult? Function( CoreError_PushRejected value)?  pushRejected,TResult? Function( CoreError_Network value)?  network,TResult? Function( CoreError_GitHub value)?  gitHub,TResult? Function( CoreError_Integrity value)?  integrity,TResult? Function( CoreError_InvalidInput value)?  invalidInput,TResult? Function( CoreError_Io value)?  io,TResult? Function( CoreError_Git value)?  git,}){
final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that);case CoreError_NothingToCommit() when nothingToCommit != null:
return nothingToCommit(_that);case CoreError_MissingIdentity() when missingIdentity != null:
return missingIdentity(_that);case CoreError_Conflicts() when conflicts != null:
return conflicts(_that);case CoreError_NotFastForward() when notFastForward != null:
return notFastForward(_that);case CoreError_DirtyWorktree() when dirtyWorktree != null:
return dirtyWorktree(_that);case CoreError_BranchNotMerged() when branchNotMerged != null:
return branchNotMerged(_that);case CoreError_NoUpstream() when noUpstream != null:
return noUpstream(_that);case CoreError_DetachedHead() when detachedHead != null:
return detachedHead(_that);case CoreError_Auth() when auth != null:
return auth(_that);case CoreError_PushRejected() when pushRejected != null:
return pushRejected(_that);case CoreError_Network() when network != null:
return network(_that);case CoreError_GitHub() when gitHub != null:
return gitHub(_that);case CoreError_Integrity() when integrity != null:
return integrity(_that);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that);case CoreError_Io() when io != null:
return io(_that);case CoreError_Git() when git != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String path)?  notARepository,TResult Function( String path)?  pathNotFound,TResult Function()?  nothingToCommit,TResult Function()?  missingIdentity,TResult Function( List<String> files)?  conflicts,TResult Function()?  notFastForward,TResult Function( String message)?  dirtyWorktree,TResult Function( String name)?  branchNotMerged,TResult Function( String branch)?  noUpstream,TResult Function()?  detachedHead,TResult Function( String message)?  auth,TResult Function( String message)?  pushRejected,TResult Function( String message)?  network,TResult Function( int status,  String message)?  gitHub,TResult Function( String message)?  integrity,TResult Function( String message)?  invalidInput,TResult Function( String message)?  io,TResult Function( String message)?  git,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that.path);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that.path);case CoreError_NothingToCommit() when nothingToCommit != null:
return nothingToCommit();case CoreError_MissingIdentity() when missingIdentity != null:
return missingIdentity();case CoreError_Conflicts() when conflicts != null:
return conflicts(_that.files);case CoreError_NotFastForward() when notFastForward != null:
return notFastForward();case CoreError_DirtyWorktree() when dirtyWorktree != null:
return dirtyWorktree(_that.message);case CoreError_BranchNotMerged() when branchNotMerged != null:
return branchNotMerged(_that.name);case CoreError_NoUpstream() when noUpstream != null:
return noUpstream(_that.branch);case CoreError_DetachedHead() when detachedHead != null:
return detachedHead();case CoreError_Auth() when auth != null:
return auth(_that.message);case CoreError_PushRejected() when pushRejected != null:
return pushRejected(_that.message);case CoreError_Network() when network != null:
return network(_that.message);case CoreError_GitHub() when gitHub != null:
return gitHub(_that.status,_that.message);case CoreError_Integrity() when integrity != null:
return integrity(_that.message);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that.message);case CoreError_Io() when io != null:
return io(_that.message);case CoreError_Git() when git != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String path)  notARepository,required TResult Function( String path)  pathNotFound,required TResult Function()  nothingToCommit,required TResult Function()  missingIdentity,required TResult Function( List<String> files)  conflicts,required TResult Function()  notFastForward,required TResult Function( String message)  dirtyWorktree,required TResult Function( String name)  branchNotMerged,required TResult Function( String branch)  noUpstream,required TResult Function()  detachedHead,required TResult Function( String message)  auth,required TResult Function( String message)  pushRejected,required TResult Function( String message)  network,required TResult Function( int status,  String message)  gitHub,required TResult Function( String message)  integrity,required TResult Function( String message)  invalidInput,required TResult Function( String message)  io,required TResult Function( String message)  git,}) {final _that = this;
switch (_that) {
case CoreError_NotARepository():
return notARepository(_that.path);case CoreError_PathNotFound():
return pathNotFound(_that.path);case CoreError_NothingToCommit():
return nothingToCommit();case CoreError_MissingIdentity():
return missingIdentity();case CoreError_Conflicts():
return conflicts(_that.files);case CoreError_NotFastForward():
return notFastForward();case CoreError_DirtyWorktree():
return dirtyWorktree(_that.message);case CoreError_BranchNotMerged():
return branchNotMerged(_that.name);case CoreError_NoUpstream():
return noUpstream(_that.branch);case CoreError_DetachedHead():
return detachedHead();case CoreError_Auth():
return auth(_that.message);case CoreError_PushRejected():
return pushRejected(_that.message);case CoreError_Network():
return network(_that.message);case CoreError_GitHub():
return gitHub(_that.status,_that.message);case CoreError_Integrity():
return integrity(_that.message);case CoreError_InvalidInput():
return invalidInput(_that.message);case CoreError_Io():
return io(_that.message);case CoreError_Git():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String path)?  notARepository,TResult? Function( String path)?  pathNotFound,TResult? Function()?  nothingToCommit,TResult? Function()?  missingIdentity,TResult? Function( List<String> files)?  conflicts,TResult? Function()?  notFastForward,TResult? Function( String message)?  dirtyWorktree,TResult? Function( String name)?  branchNotMerged,TResult? Function( String branch)?  noUpstream,TResult? Function()?  detachedHead,TResult? Function( String message)?  auth,TResult? Function( String message)?  pushRejected,TResult? Function( String message)?  network,TResult? Function( int status,  String message)?  gitHub,TResult? Function( String message)?  integrity,TResult? Function( String message)?  invalidInput,TResult? Function( String message)?  io,TResult? Function( String message)?  git,}) {final _that = this;
switch (_that) {
case CoreError_NotARepository() when notARepository != null:
return notARepository(_that.path);case CoreError_PathNotFound() when pathNotFound != null:
return pathNotFound(_that.path);case CoreError_NothingToCommit() when nothingToCommit != null:
return nothingToCommit();case CoreError_MissingIdentity() when missingIdentity != null:
return missingIdentity();case CoreError_Conflicts() when conflicts != null:
return conflicts(_that.files);case CoreError_NotFastForward() when notFastForward != null:
return notFastForward();case CoreError_DirtyWorktree() when dirtyWorktree != null:
return dirtyWorktree(_that.message);case CoreError_BranchNotMerged() when branchNotMerged != null:
return branchNotMerged(_that.name);case CoreError_NoUpstream() when noUpstream != null:
return noUpstream(_that.branch);case CoreError_DetachedHead() when detachedHead != null:
return detachedHead();case CoreError_Auth() when auth != null:
return auth(_that.message);case CoreError_PushRejected() when pushRejected != null:
return pushRejected(_that.message);case CoreError_Network() when network != null:
return network(_that.message);case CoreError_GitHub() when gitHub != null:
return gitHub(_that.status,_that.message);case CoreError_Integrity() when integrity != null:
return integrity(_that.message);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that.message);case CoreError_Io() when io != null:
return io(_that.message);case CoreError_Git() when git != null:
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


class CoreError_NothingToCommit extends CoreError {
  const CoreError_NothingToCommit(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_NothingToCommit);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreError.nothingToCommit()';
}


}




/// @nodoc


class CoreError_MissingIdentity extends CoreError {
  const CoreError_MissingIdentity(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_MissingIdentity);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreError.missingIdentity()';
}


}




/// @nodoc


class CoreError_Conflicts extends CoreError {
  const CoreError_Conflicts({required  List<String> files}): _files = files,super._();
  

 final  List<String> _files;
 List<String> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}


/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_ConflictsCopyWith<CoreError_Conflicts> get copyWith => _$CoreError_ConflictsCopyWithImpl<CoreError_Conflicts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Conflicts&&const DeepCollectionEquality().equals(other.files, _files));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_files));
}

@override
String toString() {
    return 'CoreError.conflicts(files: $files)';
}


}

/// @nodoc
abstract mixin class $CoreError_ConflictsCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_ConflictsCopyWith(CoreError_Conflicts value, $Res Function(CoreError_Conflicts) _then) = _$CoreError_ConflictsCopyWithImpl;
@useResult
$Res call({
 List<String> files
});




}
/// @nodoc
class _$CoreError_ConflictsCopyWithImpl<$Res>
    implements $CoreError_ConflictsCopyWith<$Res> {
  _$CoreError_ConflictsCopyWithImpl(this._self, this._then);

  final CoreError_Conflicts _self;
  final $Res Function(CoreError_Conflicts) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? files = null,}) {
  return _then(CoreError_Conflicts(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class CoreError_NotFastForward extends CoreError {
  const CoreError_NotFastForward(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_NotFastForward);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreError.notFastForward()';
}


}




/// @nodoc


class CoreError_DirtyWorktree extends CoreError {
  const CoreError_DirtyWorktree({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_DirtyWorktreeCopyWith<CoreError_DirtyWorktree> get copyWith => _$CoreError_DirtyWorktreeCopyWithImpl<CoreError_DirtyWorktree>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_DirtyWorktree&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.dirtyWorktree(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_DirtyWorktreeCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_DirtyWorktreeCopyWith(CoreError_DirtyWorktree value, $Res Function(CoreError_DirtyWorktree) _then) = _$CoreError_DirtyWorktreeCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_DirtyWorktreeCopyWithImpl<$Res>
    implements $CoreError_DirtyWorktreeCopyWith<$Res> {
  _$CoreError_DirtyWorktreeCopyWithImpl(this._self, this._then);

  final CoreError_DirtyWorktree _self;
  final $Res Function(CoreError_DirtyWorktree) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_DirtyWorktree(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_BranchNotMerged extends CoreError {
  const CoreError_BranchNotMerged({required this.name}): super._();
  

 final  String name;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_BranchNotMergedCopyWith<CoreError_BranchNotMerged> get copyWith => _$CoreError_BranchNotMergedCopyWithImpl<CoreError_BranchNotMerged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_BranchNotMerged&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'CoreError.branchNotMerged(name: $name)';
}


}

/// @nodoc
abstract mixin class $CoreError_BranchNotMergedCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_BranchNotMergedCopyWith(CoreError_BranchNotMerged value, $Res Function(CoreError_BranchNotMerged) _then) = _$CoreError_BranchNotMergedCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$CoreError_BranchNotMergedCopyWithImpl<$Res>
    implements $CoreError_BranchNotMergedCopyWith<$Res> {
  _$CoreError_BranchNotMergedCopyWithImpl(this._self, this._then);

  final CoreError_BranchNotMerged _self;
  final $Res Function(CoreError_BranchNotMerged) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(CoreError_BranchNotMerged(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_NoUpstream extends CoreError {
  const CoreError_NoUpstream({required this.branch}): super._();
  

 final  String branch;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_NoUpstreamCopyWith<CoreError_NoUpstream> get copyWith => _$CoreError_NoUpstreamCopyWithImpl<CoreError_NoUpstream>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_NoUpstream&&(identical(other.branch, branch) || other.branch == branch));
}


@override
int get hashCode {
    return Object.hash(runtimeType,branch);
}

@override
String toString() {
    return 'CoreError.noUpstream(branch: $branch)';
}


}

/// @nodoc
abstract mixin class $CoreError_NoUpstreamCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_NoUpstreamCopyWith(CoreError_NoUpstream value, $Res Function(CoreError_NoUpstream) _then) = _$CoreError_NoUpstreamCopyWithImpl;
@useResult
$Res call({
 String branch
});




}
/// @nodoc
class _$CoreError_NoUpstreamCopyWithImpl<$Res>
    implements $CoreError_NoUpstreamCopyWith<$Res> {
  _$CoreError_NoUpstreamCopyWithImpl(this._self, this._then);

  final CoreError_NoUpstream _self;
  final $Res Function(CoreError_NoUpstream) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? branch = null,}) {
  return _then(CoreError_NoUpstream(
branch: null == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_DetachedHead extends CoreError {
  const CoreError_DetachedHead(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_DetachedHead);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreError.detachedHead()';
}


}




/// @nodoc


class CoreError_Auth extends CoreError {
  const CoreError_Auth({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_AuthCopyWith<CoreError_Auth> get copyWith => _$CoreError_AuthCopyWithImpl<CoreError_Auth>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Auth&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.auth(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_AuthCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_AuthCopyWith(CoreError_Auth value, $Res Function(CoreError_Auth) _then) = _$CoreError_AuthCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_AuthCopyWithImpl<$Res>
    implements $CoreError_AuthCopyWith<$Res> {
  _$CoreError_AuthCopyWithImpl(this._self, this._then);

  final CoreError_Auth _self;
  final $Res Function(CoreError_Auth) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_Auth(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_PushRejected extends CoreError {
  const CoreError_PushRejected({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_PushRejectedCopyWith<CoreError_PushRejected> get copyWith => _$CoreError_PushRejectedCopyWithImpl<CoreError_PushRejected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_PushRejected&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.pushRejected(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_PushRejectedCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_PushRejectedCopyWith(CoreError_PushRejected value, $Res Function(CoreError_PushRejected) _then) = _$CoreError_PushRejectedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_PushRejectedCopyWithImpl<$Res>
    implements $CoreError_PushRejectedCopyWith<$Res> {
  _$CoreError_PushRejectedCopyWithImpl(this._self, this._then);

  final CoreError_PushRejected _self;
  final $Res Function(CoreError_PushRejected) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_PushRejected(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_Network extends CoreError {
  const CoreError_Network({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_NetworkCopyWith<CoreError_Network> get copyWith => _$CoreError_NetworkCopyWithImpl<CoreError_Network>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Network&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.network(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_NetworkCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_NetworkCopyWith(CoreError_Network value, $Res Function(CoreError_Network) _then) = _$CoreError_NetworkCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_NetworkCopyWithImpl<$Res>
    implements $CoreError_NetworkCopyWith<$Res> {
  _$CoreError_NetworkCopyWithImpl(this._self, this._then);

  final CoreError_Network _self;
  final $Res Function(CoreError_Network) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_Network(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_GitHub extends CoreError {
  const CoreError_GitHub({required this.status, required this.message}): super._();
  

 final  int status;
 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_GitHubCopyWith<CoreError_GitHub> get copyWith => _$CoreError_GitHubCopyWithImpl<CoreError_GitHub>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_GitHub&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,message);
}

@override
String toString() {
    return 'CoreError.gitHub(status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_GitHubCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_GitHubCopyWith(CoreError_GitHub value, $Res Function(CoreError_GitHub) _then) = _$CoreError_GitHubCopyWithImpl;
@useResult
$Res call({
 int status, String message
});




}
/// @nodoc
class _$CoreError_GitHubCopyWithImpl<$Res>
    implements $CoreError_GitHubCopyWith<$Res> {
  _$CoreError_GitHubCopyWithImpl(this._self, this._then);

  final CoreError_GitHub _self;
  final $Res Function(CoreError_GitHub) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? status = null,Object? message = null,}) {
  return _then(CoreError_GitHub(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_Integrity extends CoreError {
  const CoreError_Integrity({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_IntegrityCopyWith<CoreError_Integrity> get copyWith => _$CoreError_IntegrityCopyWithImpl<CoreError_Integrity>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Integrity&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.integrity(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_IntegrityCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_IntegrityCopyWith(CoreError_Integrity value, $Res Function(CoreError_Integrity) _then) = _$CoreError_IntegrityCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_IntegrityCopyWithImpl<$Res>
    implements $CoreError_IntegrityCopyWith<$Res> {
  _$CoreError_IntegrityCopyWithImpl(this._self, this._then);

  final CoreError_Integrity _self;
  final $Res Function(CoreError_Integrity) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_Integrity(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_InvalidInput extends CoreError {
  const CoreError_InvalidInput({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_InvalidInputCopyWith<CoreError_InvalidInput> get copyWith => _$CoreError_InvalidInputCopyWithImpl<CoreError_InvalidInput>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_InvalidInput&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.invalidInput(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_InvalidInputCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_InvalidInputCopyWith(CoreError_InvalidInput value, $Res Function(CoreError_InvalidInput) _then) = _$CoreError_InvalidInputCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_InvalidInputCopyWithImpl<$Res>
    implements $CoreError_InvalidInputCopyWith<$Res> {
  _$CoreError_InvalidInputCopyWithImpl(this._self, this._then);

  final CoreError_InvalidInput _self;
  final $Res Function(CoreError_InvalidInput) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_InvalidInput(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_Io extends CoreError {
  const CoreError_Io({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_IoCopyWith<CoreError_Io> get copyWith => _$CoreError_IoCopyWithImpl<CoreError_Io>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Io&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.io(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_IoCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_IoCopyWith(CoreError_Io value, $Res Function(CoreError_Io) _then) = _$CoreError_IoCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_IoCopyWithImpl<$Res>
    implements $CoreError_IoCopyWith<$Res> {
  _$CoreError_IoCopyWithImpl(this._self, this._then);

  final CoreError_Io _self;
  final $Res Function(CoreError_Io) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_Io(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
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
