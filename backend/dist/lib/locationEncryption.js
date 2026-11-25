import { createCipheriv, createDecipheriv, randomBytes, } from 'node:crypto';
const ENVELOPE_VERSION = '__karipaLocationEncryptionV1';
const ALGORITHM = 'aes-256-gcm';
export class LocationDataEncryptionError extends Error {
    constructor(message) {
        super(message);
        this.name = 'LocationDataEncryptionError';
    }
}
export function hasLocationData(value) {
    if (value === null || value === undefined)
        return false;
    if (Array.isArray(value))
        return value.length > 0;
    if (typeof value === 'object')
        return Object.keys(value).length > 0;
    return true;
}
function getEncryptionKey() {
    const configuredKey = process.env.LOCATION_DATA_ENCRYPTION_KEY?.trim();
    if (!configuredKey) {
        throw new LocationDataEncryptionError('LOCATION_DATA_ENCRYPTION_KEY must be configured to read or write location data.');
    }
    const key = Buffer.from(configuredKey, 'base64');
    if (key.length !== 32 || key.toString('base64') !== configuredKey) {
        throw new LocationDataEncryptionError('LOCATION_DATA_ENCRYPTION_KEY must be a base64-encoded 32-byte key.');
    }
    return key;
}
export function isEncryptedLocationData(value) {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return false;
    }
    const envelope = value;
    return envelope[ENVELOPE_VERSION] === 1;
}
export function encryptLocationData(value) {
    const serializedValue = JSON.stringify(value);
    if (serializedValue === undefined) {
        throw new LocationDataEncryptionError('Location data must be JSON serializable.');
    }
    if (!hasLocationData(value)) {
        return JSON.parse(serializedValue);
    }
    const key = getEncryptionKey();
    const iv = randomBytes(12);
    const cipher = createCipheriv(ALGORITHM, key, iv);
    const ciphertext = Buffer.concat([
        cipher.update(serializedValue, 'utf8'),
        cipher.final(),
    ]);
    return {
        [ENVELOPE_VERSION]: 1,
        iv: iv.toString('base64'),
        authTag: cipher.getAuthTag().toString('base64'),
        ciphertext: ciphertext.toString('base64'),
    };
}
export function decryptLocationData(value) {
    if (!isEncryptedLocationData(value))
        return value;
    const key = getEncryptionKey();
    const envelope = value;
    if (typeof envelope.iv !== 'string' ||
        typeof envelope.authTag !== 'string' ||
        typeof envelope.ciphertext !== 'string') {
        throw new LocationDataEncryptionError('Stored location data has an invalid encrypted envelope.');
    }
    try {
        const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(envelope.iv, 'base64'));
        decipher.setAuthTag(Buffer.from(envelope.authTag, 'base64'));
        const plaintext = Buffer.concat([
            decipher.update(Buffer.from(envelope.ciphertext, 'base64')),
            decipher.final(),
        ]).toString('utf8');
        return JSON.parse(plaintext);
    }
    catch (error) {
        if (error instanceof LocationDataEncryptionError)
            throw error;
        throw new LocationDataEncryptionError('Could not decrypt stored location data. Verify the configured encryption key.');
    }
}
