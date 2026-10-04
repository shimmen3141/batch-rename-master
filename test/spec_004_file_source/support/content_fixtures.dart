// 004 REQ-010 の①を確かめる fixture を組み立てる(`010:T02`)。
//
// 第三者の画像を repository に置かないため、各形式の仕様の最小限を byte で組む。
// **読む側と同じ思い込みで作っていないか**は、実在のサンプルでの確認(`010:T02` の
// task.md)と、端末の写真・動画(`010:T03` の manual)が補う。

import 'dart:typed_data';

class FixtureBytes {
  final _builder = BytesBuilder();

  void u8(int v) => _builder.addByte(v);
  void u16(int v, [Endian e = Endian.big]) =>
      _builder.add((ByteData(2)..setUint16(0, v, e)).buffer.asUint8List());
  void u32(int v, [Endian e = Endian.big]) =>
      _builder.add((ByteData(4)..setUint32(0, v, e)).buffer.asUint8List());
  void u64(int v) =>
      _builder.add((ByteData(8)..setUint64(0, v)).buffer.asUint8List());
  void ascii(String s) => _builder.add(s.codeUnits);
  void bytes(List<int> b) => _builder.add(b);
  int get length => _builder.length;
  Uint8List take() => _builder.takeBytes();
}

/// EXIF の TIFF 構造。IFD0 に Exif IFD への pointer、Exif IFD に DateTimeOriginal
/// (と、あれば OffsetTimeOriginal)。IFD0 には紛らわしい DateTime(0x0132)も置く。
Uint8List tiff({
  required String dateTimeOriginal,
  String? offsetTimeOriginal,
  String modifyDateTime = '1999:01:01 00:00:00',
  Endian endian = Endian.little,
}) {
  final b = FixtureBytes();
  b.ascii(endian == Endian.little ? 'II' : 'MM');
  b.u16(42, endian);
  b.u32(8, endian); // IFD0
  // IFD0: 2 entries → 2 + 24 + 4 = 30 byte(8..38)。値の領域は 38 から。
  const ifd0 = 8;
  const ifd0Size = 2 + 2 * 12 + 4;
  const modifyAt = ifd0 + ifd0Size; // 38, 20 byte
  const exifIfd = modifyAt + 20; // 58
  final exifEntries = offsetTimeOriginal == null ? 1 : 2;
  final exifSize = 2 + exifEntries * 12 + 4;
  final originalAt = exifIfd + exifSize;
  final offsetAt = originalAt + 20;
  b.u16(2, endian);
  b.u16(0x0132, endian); // DateTime(更新)。読んではいけない
  b.u16(2, endian);
  b.u32(20, endian);
  b.u32(modifyAt, endian);
  b.u16(0x8769, endian); // Exif IFD pointer
  b.u16(4, endian);
  b.u32(1, endian);
  b.u32(exifIfd, endian);
  b.u32(0, endian);
  b.ascii('$modifyDateTime\u0000');
  b.u16(exifEntries, endian);
  b.u16(0x9003, endian);
  b.u16(2, endian);
  b.u32(20, endian);
  b.u32(originalAt, endian);
  if (offsetTimeOriginal != null) {
    b.u16(0x9011, endian);
    b.u16(2, endian);
    b.u32(7, endian);
    b.u32(offsetAt, endian);
  }
  b.u32(0, endian);
  b.ascii('$dateTimeOriginal\u0000');
  if (offsetTimeOriginal != null) b.ascii('$offsetTimeOriginal\u0000');
  return b.take();
}

/// JPEG: SOI、APP0(JFIF)、APP1(Exif)、SOS。
Uint8List jpeg(Uint8List exifTiff, {bool exifFirst = false}) {
  final b = FixtureBytes();
  b.bytes([0xFF, 0xD8]);
  void app0() {
    b.bytes([0xFF, 0xE0]);
    b.u16(16);
    b.ascii('JFIF\u0000');
    b.bytes([1, 1, 0, 0, 1, 0, 1, 0, 0]);
  }

  if (!exifFirst) app0();
  b.bytes([0xFF, 0xE1]);
  b.u16(2 + 6 + exifTiff.length);
  b.ascii('Exif\u0000\u0000');
  b.bytes(exifTiff);
  if (exifFirst) app0();
  b.bytes([0xFF, 0xDA, 0x00, 0x02, 0x00, 0x00, 0xFF, 0xD9]);
  return b.take();
}

Uint8List box(String type, List<int> content) {
  final b = FixtureBytes();
  b.u32(8 + content.length);
  b.ascii(type);
  b.bytes(content);
  return b.take();
}

Uint8List fullBox(String type, int version, List<int> content) =>
    box(type, [version, 0, 0, 0, ...content]);

Uint8List ftyp(String brand) =>
    box('ftyp', [...brand.codeUnits, 0, 0, 0, 0, ...brand.codeUnits]);

/// HEIF: ftyp、meta(hdlr・iinf・iloc)、mdat(Exif の中身)。
///
/// [ilocVersion] 0 / 1、[infeVersion] 2 / 3 を選べる。Exif の中身は
/// 「TIFF までの offset(4 byte)」+ `Exif\0\0` + TIFF。
Uint8List heif(
  Uint8List exifTiff, {
  int ilocVersion = 0,
  int infeVersion = 2,
  int exifId = 2,
}) {
  final exifPayload = FixtureBytes()
    ..u32(6)
    ..ascii('Exif\u0000\u0000')
    ..bytes(exifTiff);
  final payload = exifPayload.take();

  Uint8List infe(int id, String type) {
    final c = FixtureBytes();
    if (infeVersion == 2) {
      c.u16(id);
    } else {
      c.u32(id);
    }
    c.u16(0);
    c.ascii(type);
    c.u8(0); // item_name ""
    return fullBox('infe', infeVersion, c.take());
  }

  final iinfContent = FixtureBytes()
    ..u16(2)
    ..bytes(infe(1, 'hvc1'))
    ..bytes(infe(exifId, 'Exif'));
  final iinf = fullBox('iinf', 0, iinfContent.take());
  final hdlr = fullBox('hdlr', 0, [
    0,
    0,
    0,
    0,
    ...'pict'.codeUnits,
    ...List.filled(13, 0),
  ]);

  Uint8List iloc(int exifOffset) {
    final c = FixtureBytes();
    c.u8(0x44); // offset_size 4, length_size 4
    c.u8(ilocVersion == 0 ? 0x00 : 0x00); // base_offset_size 0, index_size 0
    c.u16(2);
    void item(int id, int offset, int length) {
      c.u16(id);
      if (ilocVersion == 1) c.u16(0); // construction_method 0
      c.u16(0); // data_reference_index
      c.u16(1); // extent_count
      c.u32(offset);
      c.u32(length);
    }

    item(1, 0, 0);
    item(exifId, exifOffset, payload.length);
    return fullBox('iloc', ilocVersion, c.take());
  }

  // 位置を決めるため、いったん offset 0 で組んでから長さを測る。
  final ftypBox = ftyp('heic');
  Uint8List metaWith(int exifOffset) =>
      fullBox('meta', 0, [...hdlr, ...iinf, ...iloc(exifOffset)]);
  final metaLength = metaWith(0).length;
  final exifOffset = ftypBox.length + metaLength + 8; // mdat の header の後
  return Uint8List.fromList([
    ...ftypBox,
    ...metaWith(exifOffset),
    ...box('mdat', payload),
  ]);
}

const mp4Epoch = 2082844800;

/// MP4: ftyp、(mdat)、moov(mvhd)。[moovLast] なら mdat の後に moov。
Uint8List mp4({
  required int creationSeconds1904,
  int version = 0,
  bool moovLast = false,
  String brand = 'isom',
}) {
  final mvhd = FixtureBytes();
  if (version == 1) {
    mvhd.u64(creationSeconds1904);
    mvhd.u64(creationSeconds1904);
    mvhd.u32(1000);
    mvhd.u64(0);
  } else {
    mvhd.u32(creationSeconds1904);
    mvhd.u32(creationSeconds1904);
    mvhd.u32(1000);
    mvhd.u32(0);
  }
  mvhd.bytes(List.filled(80, 0));
  final moov = box('moov', [
    ...box('udta', []),
    ...fullBox('mvhd', version, mvhd.take()),
  ]);
  final mdat = box('mdat', List.filled(64, 0x55));
  return Uint8List.fromList([
    ...ftyp(brand),
    if (moovLast) ...mdat,
    ...moov,
    if (!moovLast) ...mdat,
  ]);
}

int utcSeconds1904(DateTime utc) =>
    utc.millisecondsSinceEpoch ~/ 1000 + mp4Epoch;
