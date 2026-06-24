import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 문구 음성(PCM16/24kHz)을 기기에 캐시해 네트워크 없이 재생.
///
/// 키 = 대상 언어 + 문구 텍스트. 파일명은 base64url로 결정적 인코딩.
class PhraseCache {
  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/phrase_cache');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  String _name(String lang, String text) =>
      '${lang}_${base64Url.encode(utf8.encode(text))}.pcm';

  Future<File> _file(String lang, String text) async =>
      File('${(await _ensureDir()).path}/${_name(lang, text)}');

  /// 캐시된 음성 반환(없으면 null).
  Future<Uint8List?> get(String lang, String text) async {
    final f = await _file(lang, text);
    return await f.exists() ? await f.readAsBytes() : null;
  }

  Future<bool> has(String lang, String text) async =>
      (await _file(lang, text)).exists();

  Future<void> put(String lang, String text, Uint8List bytes) async {
    final f = await _file(lang, text);
    await f.writeAsBytes(bytes, flush: true);
  }
}
