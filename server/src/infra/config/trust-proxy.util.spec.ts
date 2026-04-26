import { parseTrustProxySetting } from './trust-proxy.util';

describe('parseTrustProxySetting', () => {
  it('should default to false when trust proxy is not configured', () => {
    expect(parseTrustProxySetting(undefined)).toBe(false);
    expect(parseTrustProxySetting('')).toBe(false);
  });

  it('should parse booleans and hop counts', () => {
    expect(parseTrustProxySetting('true')).toBe(true);
    expect(parseTrustProxySetting('false')).toBe(false);
    expect(parseTrustProxySetting('2')).toBe(2);
  });

  it('should preserve trusted proxy names and CIDR lists', () => {
    expect(parseTrustProxySetting('loopback')).toBe('loopback');
    expect(parseTrustProxySetting('loopback, linklocal')).toEqual([
      'loopback',
      'linklocal',
    ]);
  });
});
