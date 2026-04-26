export type TrustProxySetting = boolean | number | string | string[];

export function parseTrustProxySetting(
  rawValue: string | undefined,
): TrustProxySetting {
  if (!rawValue) {
    return false;
  }

  const normalized = rawValue.trim();

  if (normalized.length === 0) {
    return false;
  }

  const lowerCased = normalized.toLowerCase();

  if (lowerCased === 'true') {
    return true;
  }

  if (lowerCased === 'false') {
    return false;
  }

  if (/^\d+$/.test(normalized)) {
    return Number(normalized);
  }

  if (normalized.includes(',')) {
    return normalized
      .split(',')
      .map((segment) => segment.trim())
      .filter((segment) => segment.length > 0);
  }

  return normalized;
}
