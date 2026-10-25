// The on-device engines use dart:ffi; a platform without it gets none
// (plan.md section 33).
export 'local_engines_none.dart' if (dart.library.ffi) 'local_engines_ffi.dart';
