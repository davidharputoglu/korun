import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Dates création/accès/modification sous Windows via Win32.
/// - Lecture de la date de création : FindFirstFile (WIN32_FIND_DATA),
///   API garantie présente dans toutes les versions du paquet win32.
/// - Écriture des trois dates : SetFileTime.
/// Sous Linux, le noyau n'expose aucune API pour écrire btime :
/// la date de création y reste lecture seule (message explicite dans l'UI).
class WindowsTimes {
  static final DateTime _epoch1601 = DateTime.utc(1601, 1, 1);

  static DateTime? getCreation(String path) {
    if (!Platform.isWindows) return null;
    final nativePath = path.toNativeUtf16();
    final fd = calloc<WIN32_FIND_DATA>();
    try {
      final h = FindFirstFile(nativePath, fd);
      if (h == INVALID_HANDLE_VALUE) return null;
      FindClose(h);
      return _fromFileTime(fd.ref.ftCreationTime);
    } catch (_) {
      return null;
    } finally {
      calloc.free(fd);
      calloc.free(nativePath);
    }
  }

  static Future<bool> setTimes(
    String path, {
    DateTime? created,
    DateTime? accessed,
    DateTime? modified,
  }) async {
    if (!Platform.isWindows) return false;
    final nativePath = path.toNativeUtf16();
    final h = CreateFile(
      nativePath,
      FILE_WRITE_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE,
      nullptr,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      0,
    );
    calloc.free(nativePath);
    if (h == INVALID_HANDLE_VALUE) return false;
    final pc = created == null ? nullptr : calloc<FILETIME>();
    final pa = accessed == null ? nullptr : calloc<FILETIME>();
    final pm = modified == null ? nullptr : calloc<FILETIME>();
    try {
      if (created != null) _fill(pc, created);
      if (accessed != null) _fill(pa, accessed);
      if (modified != null) _fill(pm, modified);
      return SetFileTime(h, pc, pa, pm) != 0;
    } finally {
      CloseHandle(h);
      if (created != null) calloc.free(pc);
      if (accessed != null) calloc.free(pa);
      if (modified != null) calloc.free(pm);
    }
  }

  static void _fill(Pointer<FILETIME> ft, DateTime d) {
    final intervals = d.toUtc().difference(_epoch1601).inMicroseconds * 10;
    ft.ref.dwLowDateTime = intervals & 0xFFFFFFFF;
    ft.ref.dwHighDateTime = (intervals >> 32) & 0xFFFFFFFF;
  }

  static DateTime _fromFileTime(FILETIME ft) {
    final intervals =
        (ft.dwHighDateTime.toUnsigned(32) << 32) | ft.dwLowDateTime.toUnsigned(32);
    return _epoch1601.add(Duration(microseconds: intervals ~/ 10)).toLocal();
  }
}
