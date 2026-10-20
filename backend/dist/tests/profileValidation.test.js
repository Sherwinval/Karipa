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
