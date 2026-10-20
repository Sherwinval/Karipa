const MANILA_UTC_OFFSET_MS = 8 * 60 * 60 * 1000;
const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;

export function getWeeklyLeaderboardPeriod(now = new Date()) {
  const manilaNow = new Date(now.getTime() + MANILA_UTC_OFFSET_MS);
  const manilaMidnightUtc = Date.UTC(
    manilaNow.getUTCFullYear(),
    manilaNow.getUTCMonth(),
    manilaNow.getUTCDate(),
  );
  const sundayMidnightManilaUtc =
    manilaMidnightUtc - manilaNow.getUTCDay() * MILLISECONDS_PER_DAY;

  return {
    periodStart: new Date(sundayMidnightManilaUtc - MANILA_UTC_OFFSET_MS),
    periodEnd: now,
  };
}
