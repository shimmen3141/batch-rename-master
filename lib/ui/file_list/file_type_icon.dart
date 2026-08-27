import 'package:flutter/material.dart';

import '../../data/preview/file_preview.dart';

/// 拡張子から行のアイコンを決める(008:T07)。**表示専用である。**
///
/// preview を出せない file(文書・書庫・不明な拡張子)と、preview がまだ届いていない
/// 行の下地になる。**読み込み対象の絞り込み(004 REQ-011 の種類)にも、改名の判定にも
/// 使わない** — 004 の決定 D-2「実装が返したものをそのまま扱う」を曲げないこと。
/// ここで種別を推測して読み込む file を変えてはならない。
///
/// 判定できない拡張子は汎用の file アイコンにする。**間違ったアイコンより、
/// 何も主張しないアイコンの方がまし**である。
IconData fileTypeIconOf(String fileName) {
  switch (previewKindOf(fileName)) {
    case PreviewKind.image:
      return Icons.image_outlined;
    case PreviewKind.video:
      return Icons.movie_outlined;
    case PreviewKind.other:
      break;
  }
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) {
    return Icons.insert_drive_file_outlined;
  }
  final extension = fileName.substring(dot + 1).toLowerCase();
  if (_documentExtensions.contains(extension)) {
    return Icons.description_outlined;
  }
  if (_archiveExtensions.contains(extension)) return Icons.folder_zip_outlined;
  if (_audioExtensions.contains(extension)) return Icons.audiotrack_outlined;
  return Icons.insert_drive_file_outlined;
}

const _documentExtensions = {
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
  'md',
  'csv',
  'rtf',
};

const _archiveExtensions = {'zip', 'gz', 'tar', 'rar', '7z', 'bz2', 'xz'};

const _audioExtensions = {'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus'};
