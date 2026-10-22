import 'dart:typed_data';

class PcmWav {
  PcmWav(this.sampleRate, this.pcm);
  final int sampleRate;
  final Uint8List pcm;
  double get duration => pcm.length / (sampleRate * 2);
  factory PcmWav.parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      throw const FormatException('Expected RIFF WAV');
    }
    int? rate;
    Uint8List? pcm;
    for (var offset = 12; offset + 8 <= bytes.length;) {
      final size = data.getUint32(offset + 4, Endian.little),
          start = offset + 8;
      if (start + size > bytes.length) {
        throw const FormatException('Truncated WAV chunk');
      }
      if (tag(offset) == 'fmt ') {
        if (size < 16 ||
            data.getUint16(start, Endian.little) != 1 ||
            data.getUint16(start + 2, Endian.little) != 1 ||
            data.getUint16(start + 14, Endian.little) != 16) {
          throw const FormatException(
            'Streaming simulation requires mono PCM16 WAV',
          );
        }
        rate = data.getUint32(start + 4, Endian.little);
      }
      if (tag(offset) == 'data') {
        pcm = Uint8List.sublistView(bytes, start, start + size);
      }
      offset = start + size + (size % 2);
    }
    if (rate == null ||
        pcm == null ||
        pcm.length.isOdd ||
        rate < 8000 ||
        rate > 96000) {
      throw const FormatException('Missing/invalid WAV data');
    }
    return PcmWav(rate, pcm);
  }
}
