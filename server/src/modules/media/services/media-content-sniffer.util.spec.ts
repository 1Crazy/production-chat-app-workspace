import { objectContentMatchesMimeType } from './media-content-sniffer.util';

describe('objectContentMatchesMimeType', () => {
  it('should match supported image signatures', () => {
    expect(
      objectContentMatchesMimeType(
        'image/png',
        Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex'),
      ),
    ).toBe(true);
    expect(
      objectContentMatchesMimeType(
        'image/jpeg',
        Buffer.from('ffd8ffe000104a464946', 'hex'),
      ),
    ).toBe(true);
    expect(
      objectContentMatchesMimeType(
        'image/gif',
        Buffer.from('4749463839610100', 'hex'),
      ),
    ).toBe(true);
    expect(
      objectContentMatchesMimeType(
        'image/webp',
        Buffer.from('52494646aabbccdd57454250', 'hex'),
      ),
    ).toBe(true);
  });

  it('should match supported document container signatures', () => {
    expect(
      objectContentMatchesMimeType(
        'application/pdf',
        Buffer.from('%PDF-1.7\n'),
      ),
    ).toBe(true);
    expect(
      objectContentMatchesMimeType(
        'application/zip',
        Buffer.from('504b0304140000', 'hex'),
      ),
    ).toBe(true);
    expect(
      objectContentMatchesMimeType(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        Buffer.from('504b0304776f72642f646f63756d656e742e786d6c', 'hex'),
      ),
    ).toBe(true);
  });

  it('should reject empty or truncated buffers', () => {
    expect(
      objectContentMatchesMimeType('image/png', Buffer.alloc(0)),
    ).toBe(false);
    expect(
      objectContentMatchesMimeType(
        'image/png',
        Buffer.from('89504e47', 'hex'),
      ),
    ).toBe(false);
    expect(
      objectContentMatchesMimeType(
        'audio/aac',
        Buffer.from('ff', 'hex'),
      ),
    ).toBe(false);
  });

  it('should reject cross-format mismatches', () => {
    expect(
      objectContentMatchesMimeType('image/png', Buffer.from('%PDF-1.7\n')),
    ).toBe(false);
    expect(
      objectContentMatchesMimeType(
        'application/pdf',
        Buffer.from('89504e470d0a1a0a', 'hex'),
      ),
    ).toBe(false);
    expect(
      objectContentMatchesMimeType(
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        Buffer.from('504b0304776f72642f646f63756d656e742e786d6c', 'hex'),
      ),
    ).toBe(false);
  });

  it('should only accept plain text buffers without binary markers', () => {
    expect(
      objectContentMatchesMimeType(
        'text/plain',
        Buffer.from('hello world\nthis is text', 'utf8'),
      ),
    ).toBe(true);
    expect(
      objectContentMatchesMimeType(
        'text/plain',
        Buffer.from([0x68, 0x69, 0x00, 0x21]),
      ),
    ).toBe(false);
    expect(
      objectContentMatchesMimeType(
        'text/plain',
        Buffer.from([0x01, 0x02, 0x03, 0x04, 0x41]),
      ),
    ).toBe(false);
  });

  it('should reject unknown mime types by default', () => {
    expect(
      objectContentMatchesMimeType(
        'application/x-custom-binary',
        Buffer.from('74657374', 'hex'),
      ),
    ).toBe(false);
  });
});
