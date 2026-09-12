import '../../models/venue_model.dart' show KeysetCursor;

export '../../models/venue_model.dart' show KeysetCursor, PaginatedChunk, PageChunk;

/// Extension on [KeysetCursor] providing serialization utilities.
extension KeysetCursorCodecExtension on KeysetCursor {
  /// Encodes the cursor into an ISO-8601 UTC timestamp and ID delimited by pipe '|'.
  String encode() => '${createdAt.toUtc().toIso8601String()}|$id';
}

/// Codec for encoding and decoding [KeysetCursor] string representations.
class KeysetCursorCodec {
  KeysetCursorCodec._();

  /// Encodes [cursor] to a delimited string `timestamp|id`.
  static String encode(KeysetCursor cursor) => cursor.encode();

  /// Decodes [raw] string into a [KeysetCursor]. Returns null on malformed inputs.
  static KeysetCursor? decode(String? raw) {
    if (raw == null || !raw.contains('|')) return null;
    final idx = raw.indexOf('|');
    final dtStr = raw.substring(0, idx);
    final idStr = raw.substring(idx + 1);
    final dt = DateTime.tryParse(dtStr);
    if (dt == null || idStr.isEmpty) return null;
    return KeysetCursor(createdAt: dt, id: idStr);
  }
}
