import { describe, expect, it } from 'vitest';
import { CALORIE_METHOD_VERSION, calculateGrossSessionCalories, validateAndCalculateActivityCalories, } from '../services/calorieEstimationService.js';
describe('gross calorie estimation', () => {
    it('reproduces the documented 3.8 MET, 60 kg, 30 minute example', () => {
        expect(calculateGrossSessionCalories(3.8, 60, 30)).toBe(114);
    });
    it('does not require calorie metadata when no estimate is available', () => {
        expect(validateAndCalculateActivityCalories({
            activityType: 'walking',
            distanceMeters: 0,
            durationSeconds: 0,
            calories: null,
        })).toEqual({
            calories: null,
            calorieMetCode: null,
            calorieMetValue: null,
            calorieWeightKg: null,
            calorieDurationMinutes: null,
            calorieMethodVersion: null,
        });
    });
    it('validates and persists the published jogging calculation basis', () => {
        const result = validateAndCalculateActivityCalories({
            activityType: 'jogging',
            distanceMeters: 1000,
            durationSeconds: 600,
            averageSpeedKmh: 6,
            gpsData: [{}, {}],
            calories: 75,
            calorieMetCode: '12020',
            calorieMetValue: 7.5,
            calorieWeightKg: 60,
            calorieDurationMinutes: 10,
            calorieMethodVersion: CALORIE_METHOD_VERSION,
        });
        expect(result).toMatchObject({
            calories: 75,
            calorieMetCode: '12020',
            calorieMetValue: 7.5,
            calorieWeightKg: 60,
            calorieDurationMinutes: 10,
            calorieMethodVersion: CALORIE_METHOD_VERSION,
        });
    });
    it('accepts running only within the published speed category', () => {
        const distanceMeters = 8.2 * 1000;
        const result = validateAndCalculateActivityCalories({
            activityType: 'running',
            distanceMeters,
            durationSeconds: 3600,
            averageSpeedKmh: 8.2,
            gpsData: [{}, {}],
            calories: 510,
            calorieMetCode: '12030',
            calorieMetValue: 8.5,
            calorieWeightKg: 60,
            calorieDurationMinutes: 60,
            calorieMethodVersion: CALORIE_METHOD_VERSION,
        });
        expect(result.calories).toBe(510);
    });
    it('rejects unsupported activity context and inconsistent calculations', () => {
        const base = {
            distanceMeters: 1000,
            durationSeconds: 600,
            averageSpeedKmh: 6,
            gpsData: [{}, {}],
            calories: 75,
            calorieMetValue: 7.5,
            calorieWeightKg: 60,
            calorieDurationMinutes: 10,
            calorieMethodVersion: CALORIE_METHOD_VERSION,
        };
        expect(() => validateAndCalculateActivityCalories({
            ...base,
            activityType: 'walking',
            calorieMetCode: '17190',
        })).toThrow('not supported');
        expect(() => validateAndCalculateActivityCalories({
            ...base,
            activityType: 'jogging',
            calorieMetCode: '12020',
            calories: 74,
        })).toThrow('do not match');
        expect(() => validateAndCalculateActivityCalories({
            ...base,
            activityType: 'running',
            distanceMeters: (10 * 1000) / 6,
            calorieMetCode: '12030',
            calorieMetValue: 8.5,
            averageSpeedKmh: 10,
            calories: 85,
        })).toThrow('does not match');
    });
});
