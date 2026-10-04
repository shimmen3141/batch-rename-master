import 'dart:io';
import 'dart:typed_data';

/// ファイルの中身に記録された作成日時を読む(004 REQ-010 の①)。
///
/// 読むのは、写真の EXIF `DateTimeOriginal`(JPEG・HEIC)と、動画に記録された
/// 撮影日時(MP4・MOV などの `mvhd` の `creation_time`)である。**日時が書かれた
/// 部分だけを読み**、ファイル全体は読まない。
///
/// **読めなければ `null` を返し、例外を投げない。** 形式が違う・壊れている・
/// 開けない、はどれも「①が無い」であって、読み込み全体の失敗ではない
/// (004 REQ-010、代表例 52)。
///
/// 時刻は 004 REQ-010 の「壁時計の値」で返す:
/// - EXIF は**書かれた時刻そのまま**(時差 `OffsetTimeOriginal` があっても直さない —
///   書かれた時刻が撮影地の時刻である。代表例 44・45)。
/// - 動画の記録日時は UTC なので、**端末の時刻帯**へ直す(代表例 46)。
///
/// どちらも Dart の local の [DateTime] で返す。001 は年月日時分秒をそのまま
/// 整形する。
DateTime? readContentCreatedAt(String path) {
  RandomAccessFile? file;
  try {
    file = File(path).openSync();
    final reader = _Reader(file);
    final head = reader.bytesAt(0, 12);
    if (head == null) return null;
    if (head[0] == 0xFF && head[1] == 0xD8) return _jpegDate(reader);
    if (_fourCc(head, 4) == 'ftyp') return _isoBmffDate(reader);
    return null;
  } catch (_) {
    return null;
  } finally {
    try {
      file?.closeSync();
    } catch (_) {}
  }
}

/// 1つの box・segment に読む上限。日時が入る部分はこれより十分小さい。
/// 壊れた長さで巨大な領域を読まないための防波堤である。
const _maxChunk = 1 << 20;

/// EXIF の日時の形 `YYYY:MM:DD HH:MM:SS`。
final _exifDateTime = RegExp(
  r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
);

/// MP4 の時刻の起点(1904-01-01T00:00:00Z)から Unix 時刻の起点までの秒。
const _mp4EpochOffsetSeconds = 2082844800;

// ---- JPEG ----

DateTime? _jpegDate(_Reader reader) {
  var position = 2;
  // marker を順に辿り、APP1 の `Exif\0\0` を探す。画像本体(SOS)に入ったら止める。
  for (var guard = 0; guard < 64; guard++) {
    final marker = reader.bytesAt(position, 4);
    if (marker == null || marker[0] != 0xFF) return null;
    final type = marker[1];
    if (type == 0xDA || type == 0xD9) return null; // SOS / EOI
    final length = (marker[2] << 8) | marker[3];
    if (length < 2) return null;
    if (type == 0xE1) {
      final segment = reader.bytesAt(position + 4, length - 2);
      if (segment != null &&
          segment.length > 6 &&
          String.fromCharCodes(segment.sublist(0, 4)) == 'Exif' &&
          segment[4] == 0 &&
          segment[5] == 0) {
        return _tiffDateTimeOriginal(Uint8List.sublistView(segment, 6));
      }
    }
    position += 2 + length;
  }
  return null;
}

// ---- TIFF / EXIF ----

const _tagExifIfd = 0x8769;
const _tagDateTimeOriginal = 0x9003;

/// TIFF の構造(EXIF の本体)から `DateTimeOriginal` を読む。
DateTime? _tiffDateTimeOriginal(Uint8List tiff) {
  if (tiff.length < 8) return null;
  final data = ByteData.sublistView(tiff);
  final Endian endian;
  if (tiff[0] == 0x49 && tiff[1] == 0x49) {
    endian = Endian.little; // "II"
  } else if (tiff[0] == 0x4D && tiff[1] == 0x4D) {
    endian = Endian.big; // "MM"
  } else {
    return null;
  }
  if (data.getUint16(2, endian) != 42) return null;
  final ifd0 = data.getUint32(4, endian);
  final exifIfd = _ifdEntryValue(data, ifd0, _tagExifIfd, endian);
  if (exifIfd == null) return null;
  final entry = _ifdEntry(data, exifIfd, _tagDateTimeOriginal, endian);
  if (entry == null) return null;
  // ASCII(型2)。20 byte なので値は offset の先にある(4 byte を超える)。
  final type = data.getUint16(entry + 2, endian);
  final count = data.getUint32(entry + 4, endian);
  if (type != 2 || count < 19) return null;
  final offset = count <= 4 ? entry + 8 : data.getUint32(entry + 8, endian);
  if (offset + 19 > tiff.length) return null;
  return _parseExifDateTime(String.fromCharCodes(tiff, offset, offset + 19));
}

/// IFD の中で [tag] の entry の位置を返す。無ければ `null`。
int? _ifdEntry(ByteData data, int ifd, int tag, Endian endian) {
  if (ifd + 2 > data.lengthInBytes) return null;
  final count = data.getUint16(ifd, endian);
  for (var i = 0; i < count; i++) {
    final entry = ifd + 2 + i * 12;
    if (entry + 12 > data.lengthInBytes) return null;
    if (data.getUint16(entry, endian) == tag) return entry;
  }
  return null;
}

/// LONG の値を持つ [tag] の値(Exif IFD への offset)を返す。
int? _ifdEntryValue(ByteData data, int ifd, int tag, Endian endian) {
  final entry = _ifdEntry(data, ifd, tag, endian);
  if (entry == null) return null;
  return data.getUint32(entry + 8, endian);
}

DateTime? _parseExifDateTime(String text) {
  final match = _exifDateTime.firstMatch(text);
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final [year, month, day, hour, minute, second] = parts;
  // `0000:00:00 00:00:00` など、未設定を表す値や範囲外は「無い」として扱う。
  // DateTime は範囲外を繰り上げて別の日時にするので、ここで弾く。
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;
  final value = DateTime(year, month, day, hour, minute, second);
  if (value.month != month || value.day != day) return null; // 2月30日など
  return value;
}

// ---- ISO BMFF(HEIC・MP4・MOV) ----

DateTime? _isoBmffDate(_Reader reader) {
  final top = reader.boxes(0, reader.length);
  for (final box in top) {
    if (box.type == 'moov') return _movieDate(reader, box);
  }
  for (final box in top) {
    if (box.type == 'meta') return _heifExifDate(reader, box);
  }
  return null;
}

/// `moov` の中の `mvhd` の `creation_time`(UTC)を端末の時刻帯で返す。
DateTime? _movieDate(_Reader reader, _Box moov) {
  for (final box in reader.boxes(moov.contentStart, moov.end)) {
    if (box.type != 'mvhd') continue;
    final header = reader.bytesAt(box.contentStart, 12);
    if (header == null) return null;
    final data = ByteData.sublistView(header);
    final version = header[0];
    final seconds = version == 1
        ? data.getUint64(4, Endian.big)
        : data.getUint32(4, Endian.big);
    // 0 は「記録していない」。起点より前も実在しない。
    if (seconds <= _mp4EpochOffsetSeconds) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds - _mp4EpochOffsetSeconds) * 1000,
    );
  }
  return null;
}

/// HEIF の `meta` から `Exif` item を探し、その `DateTimeOriginal` を読む。
DateTime? _heifExifDate(_Reader reader, _Box meta) {
  // `meta` は FullBox(version と flags の 4 byte が先にある)。
  final children = reader.boxes(meta.contentStart + 4, meta.end);
  int? exifItem;
  for (final box in children) {
    if (box.type == 'iinf') exifItem = _exifItemId(reader, box);
  }
  if (exifItem == null) return null;
  for (final box in children) {
    if (box.type != 'iloc') continue;
    final extent = _itemExtent(reader, box, exifItem);
    if (extent == null) return null;
    final payload = reader.bytesAt(extent.$1, extent.$2);
    if (payload == null || payload.length < 4) return null;
    // Exif item の中身は「TIFF までの offset(4 byte)」+ 前置き + TIFF。
    final skip = ByteData.sublistView(payload).getUint32(0, Endian.big);
    final start = 4 + skip;
    if (start >= payload.length) return null;
    return _tiffDateTimeOriginal(Uint8List.sublistView(payload, start));
  }
  return null;
}

/// `iinf` の中で item type が `Exif` の item の ID。
int? _exifItemId(_Reader reader, _Box iinf) {
  final header = reader.bytesAt(iinf.contentStart, 8);
  if (header == null) return null;
  final version = header[0];
  final entriesStart = iinf.contentStart + (version == 0 ? 6 : 8);
  for (final infe in reader.boxes(entriesStart, iinf.end)) {
    if (infe.type != 'infe') continue;
    final body = reader.bytesAt(infe.contentStart, 16);
    if (body == null) continue;
    final data = ByteData.sublistView(body);
    final infeVersion = body[0];
    if (infeVersion < 2) continue;
    final (id, typeAt) = infeVersion == 2
        ? (data.getUint16(4, Endian.big), 8)
        : (data.getUint32(4, Endian.big), 10);
    if (_fourCc(body, typeAt) == 'Exif') return id;
  }
  return null;
}

/// `iloc` から [itemId] の中身の位置(file 先頭からの offset, 長さ)を返す。
///
/// 1つの extent で file の中にあるもの(construction_method 0)だけを扱う。
/// それ以外は `null`(①が無い)。
(int, int)? _itemExtent(_Reader reader, _Box iloc, int itemId) {
  final bytes = reader.bytesAt(iloc.contentStart, iloc.end - iloc.contentStart);
  if (bytes == null || bytes.length < 8) return null;
  final data = ByteData.sublistView(bytes);
  final version = bytes[0];
  final offsetSize = bytes[4] >> 4;
  final lengthSize = bytes[4] & 0x0F;
  final baseOffsetSize = bytes[5] >> 4;
  final indexSize = version == 0 ? 0 : bytes[5] & 0x0F;
  var at = 6;
  final int itemCount;
  if (version < 2) {
    itemCount = data.getUint16(at, Endian.big);
    at += 2;
  } else {
    itemCount = data.getUint32(at, Endian.big);
    at += 4;
  }
  int read(int size) {
    final value = switch (size) {
      0 => 0,
      4 => data.getUint32(at, Endian.big),
      8 => data.getUint64(at, Endian.big),
      _ => throw const FormatException('iloc の値の大きさ'),
    };
    at += size;
    return value;
  }

  for (var i = 0; i < itemCount; i++) {
    final int id;
    if (version < 2) {
      id = data.getUint16(at, Endian.big);
      at += 2;
    } else {
      id = data.getUint32(at, Endian.big);
      at += 4;
    }
    var constructionMethod = 0;
    if (version == 1 || version == 2) {
      constructionMethod = data.getUint16(at, Endian.big) & 0x0F;
      at += 2;
    }
    at += 2; // data_reference_index
    final baseOffset = read(baseOffsetSize);
    final extentCount = data.getUint16(at, Endian.big);
    at += 2;
    (int, int)? first;
    for (var e = 0; e < extentCount; e++) {
      if (indexSize > 0) read(indexSize);
      final offset = read(offsetSize);
      final length = read(lengthSize);
      first ??= (baseOffset + offset, length);
    }
    if (id != itemId) continue;
    if (constructionMethod != 0 || extentCount != 1 || first == null) {
      return null;
    }
    return first;
  }
  return null;
}

String _fourCc(Uint8List bytes, int at) =>
    String.fromCharCodes(bytes, at, at + 4);

class _Box {
  const _Box(this.type, this.contentStart, this.end);

  final String type;
  final int contentStart;
  final int end;
}

/// file を位置指定で読む。範囲外・上限超えは `null`。
class _Reader {
  _Reader(this._file) : length = _file.lengthSync();

  final RandomAccessFile _file;
  final int length;

  Uint8List? bytesAt(int position, int count) {
    if (position < 0 || count < 0 || count > _maxChunk) return null;
    if (position + count > length) return null;
    _file.setPositionSync(position);
    final bytes = _file.readSync(count);
    return bytes.length == count ? bytes : null;
  }

  /// [start] から [end] までに並ぶ box の一覧(header だけを読む)。
  List<_Box> boxes(int start, int end) {
    final result = <_Box>[];
    var position = start;
    while (position + 8 <= end && result.length < 256) {
      final header = bytesAt(position, 8);
      if (header == null) break;
      final data = ByteData.sublistView(header);
      var size = data.getUint32(0, Endian.big);
      final type = _fourCc(header, 4);
      var contentStart = position + 8;
      if (size == 1) {
        final large = bytesAt(position + 8, 8);
        if (large == null) break;
        size = ByteData.sublistView(large).getUint64(0, Endian.big);
        contentStart += 8;
      } else if (size == 0) {
        size = end - position;
      }
      if (size < contentStart - position || position + size > end) break;
      result.add(_Box(type, contentStart, position + size));
      position += size;
    }
    return result;
  }
}
