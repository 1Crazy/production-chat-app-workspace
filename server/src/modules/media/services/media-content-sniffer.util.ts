function startsWithBytes(buffer: Buffer, bytes: number[]): boolean {
  if (buffer.length < bytes.length) {
    return false;
  }

  return bytes.every((byte, index) => buffer[index] === byte);
}

function includesAscii(buffer: Buffer, value: string): boolean {
  return buffer.toString('latin1').includes(value);
}

function isZipContainer(buffer: Buffer): boolean {
  return (
    startsWithBytes(buffer, [0x50, 0x4b, 0x03, 0x04]) ||
    startsWithBytes(buffer, [0x50, 0x4b, 0x05, 0x06]) ||
    startsWithBytes(buffer, [0x50, 0x4b, 0x07, 0x08])
  );
}

function isOleCompoundFile(buffer: Buffer): boolean {
  return startsWithBytes(buffer, [
    0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1,
  ]);
}

function isProbablyPlainText(buffer: Buffer): boolean {
  let controlCount = 0;

  for (const byte of buffer) {
    if (byte === 0x00) {
      return false;
    }

    if (byte < 0x09 || (byte > 0x0d && byte < 0x20)) {
      controlCount += 1;
    }
  }

  return controlCount <= Math.max(1, Math.floor(buffer.length * 0.02));
}

export function objectContentMatchesMimeType(
  mimeType: string,
  objectHeadBytes: Buffer,
): boolean {
  const secondByte = objectHeadBytes[1] ?? 0;

  switch (mimeType) {
    case 'image/png':
      return startsWithBytes(objectHeadBytes, [
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      ]);
    case 'image/jpeg':
      return startsWithBytes(objectHeadBytes, [0xff, 0xd8, 0xff]);
    case 'image/gif':
      return (
        includesAscii(objectHeadBytes.subarray(0, 6), 'GIF87a') ||
        includesAscii(objectHeadBytes.subarray(0, 6), 'GIF89a')
      );
    case 'image/webp':
      return (
        includesAscii(objectHeadBytes.subarray(0, 4), 'RIFF') &&
        includesAscii(objectHeadBytes.subarray(8, 12), 'WEBP')
      );
    case 'audio/wav':
      return (
        includesAscii(objectHeadBytes.subarray(0, 4), 'RIFF') &&
        includesAscii(objectHeadBytes.subarray(8, 12), 'WAVE')
      );
    case 'audio/ogg':
      return includesAscii(objectHeadBytes.subarray(0, 4), 'OggS');
    case 'audio/aac':
      return (
        objectHeadBytes.length >= 2 &&
        objectHeadBytes[0] === 0xff &&
        (secondByte & 0xf6) === 0xf0
      );
    case 'audio/mpeg':
      return (
        includesAscii(objectHeadBytes.subarray(0, 3), 'ID3') ||
        (objectHeadBytes.length >= 2 &&
          objectHeadBytes[0] === 0xff &&
          (secondByte & 0xe0) === 0xe0)
      );
    case 'audio/mp4':
      return includesAscii(objectHeadBytes.subarray(4, 8), 'ftyp');
    case 'application/pdf':
      return includesAscii(objectHeadBytes.subarray(0, 5), '%PDF-');
    case 'application/zip':
      return isZipContainer(objectHeadBytes);
    case 'application/msword':
    case 'application/vnd.ms-excel':
    case 'application/vnd.ms-powerpoint':
      return isOleCompoundFile(objectHeadBytes);
    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      return isZipContainer(objectHeadBytes) && includesAscii(objectHeadBytes, 'word/');
    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      return isZipContainer(objectHeadBytes) && includesAscii(objectHeadBytes, 'xl/');
    case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      return isZipContainer(objectHeadBytes) && includesAscii(objectHeadBytes, 'ppt/');
    case 'text/plain':
      return isProbablyPlainText(objectHeadBytes);
    default:
      // 未显式支持的 MIME 一律拒绝，避免新增类型时出现静默放行。
      return false;
  }
}
