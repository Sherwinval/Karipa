import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  decryptLocationData,
  encryptLocationData,
  LocationDataEncryptionError,
} from '../lib/locationEncryption.js';

const key = Buffer.alloc(32, 7).toString('base64');

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('location data encryption', () => {
  it('encrypts and decrypts coordinate JSON with the configured key', () => {
    vi.stubEnv('LOCATION_DATA_ENCRYPTION_KEY', key);
    const coordinates = [
      { latitude: 14.5995, longitude: 120.9842 },
      { latitude: 14.6, longitude: 120.985 },
    ];

    const encrypted = encryptLocationData(coordinates);

    expect(encrypted).not.toEqual(coordinates);
    expect(JSON.stringify(encrypted)).not.toContain('120.9842');
    expect(decryptLocationData(encrypted)).toEqual(coordinates);
  });

  it('rejects a wrong key instead of returning unreadable or plaintext data', () => {
    vi.stubEnv('LOCATION_DATA_ENCRYPTION_KEY', key);
    const encrypted = encryptLocationData({ longitude: 120.9842 });
    vi.stubEnv(
      'LOCATION_DATA_ENCRYPTION_KEY',
      Buffer.alloc(32, 8).toString('base64'),
    );

    expect(() => decryptLocationData(encrypted)).toThrow(
      LocationDataEncryptionError,
    );
  });

  it('requires a valid key before writing location data', () => {
    vi.stubEnv('LOCATION_DATA_ENCRYPTION_KEY', '');

    expect(() => encryptLocationData({ latitude: 14.5995 })).toThrow(
      /LOCATION_DATA_ENCRYPTION_KEY must be configured/,
    );
  });

  it('leaves empty location fields unchanged because they contain no coordinates', () => {
    vi.stubEnv('LOCATION_DATA_ENCRYPTION_KEY', '');

    expect(encryptLocationData({})).toEqual({});
    expect(encryptLocationData([])).toEqual([]);
  });
});
