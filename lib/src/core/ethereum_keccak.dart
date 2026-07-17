import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';

String ethereumKeccak256(String value) {
  final digest =
      KeccakDigest(256).process(Uint8List.fromList(utf8.encode(value)));
  return '0x${digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}
