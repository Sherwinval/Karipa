import { describe, expect, it } from 'vitest';
import { profileUpdateSchema, registrationSchema } from '../routes/auth.js';
describe('optional registration measurements', () => {
    const credentials = {
        name: 'Alex Santos',
        email: 'alex@example.com',
        password: 'password123',
    };
    it('accepts registration without measurements or with either measurement', () => {
        expect(registrationSchema.safeParse(credentials).success).toBe(true);
        expect(registrationSchema.safeParse({ ...credentials, heightCm: 168 }).success).toBe(true);
        expect(registrationSchema.safeParse({ ...credentials, weightKg: 62 }).success).toBe(true);
        expect(registrationSchema.safeParse({
            ...credentials,
            heightCm: 168,
            weightKg: 62,
        }).success).toBe(true);
    });
    it('rejects invalid optional measurements', () => {
        expect(registrationSchema.safeParse({ ...credentials, heightCm: 0 }).success).toBe(false);
        expect(registrationSchema.safeParse({ ...credentials, weightKg: -1 }).success).toBe(false);
        expect(registrationSchema.safeParse({ ...credentials, weightKg: '62' }).success).toBe(false);
    });
});
describe('optional profile measurement validation', () => {
    it('accepts a non-empty profile name', () => {
        expect(profileUpdateSchema.safeParse({ name: '  Alex Santos  ' }).success).toBe(true);
        expect(profileUpdateSchema.safeParse({ name: 'Alex', heightCm: 170 }).success).toBe(true);
    });
    it('rejects empty or overly long profile names', () => {
        expect(profileUpdateSchema.safeParse({ name: '   ' }).success).toBe(false);
        expect(profileUpdateSchema.safeParse({ name: 'A'.repeat(81) }).success).toBe(false);
    });
    it('accepts supported profile photos and rejects invalid photo data', () => {
        expect(profileUpdateSchema.safeParse({
            photoData: 'data:image/jpeg;base64,aGVsbG8=',
        }).success).toBe(true);
        expect(profileUpdateSchema.safeParse({ photoData: null }).success).toBe(true);
        expect(profileUpdateSchema.safeParse({
            photoData: 'data:image/svg+xml;base64,PHN2Zz4=',
        }).success).toBe(false);
        expect(profileUpdateSchema.safeParse({
            photoData: `data:image/png;base64,${'a'.repeat(3_500_001)}`,
        }).success).toBe(false);
    });
    it('accepts independently optional positive centimeter and kilogram values', () => {
        expect(profileUpdateSchema.safeParse({ heightCm: 170 }).success).toBe(true);
        expect(profileUpdateSchema.safeParse({ weightKg: 65 }).success).toBe(true);
        expect(profileUpdateSchema.safeParse({ heightCm: null, weightKg: null }).success).toBe(true);
    });
    it('rejects non-positive, non-finite, non-numeric, and empty updates', () => {
        expect(profileUpdateSchema.safeParse({ heightCm: 0 }).success).toBe(false);
        expect(profileUpdateSchema.safeParse({ weightKg: -1 }).success).toBe(false);
        expect(profileUpdateSchema.safeParse({ weightKg: Number.POSITIVE_INFINITY }).success).toBe(false);
        expect(profileUpdateSchema.safeParse({ weightKg: '65' }).success).toBe(false);
        expect(profileUpdateSchema.safeParse({}).success).toBe(false);
    });
});
