// Release fallback: current local calendar day and no seeded facilities.
import {dashboardClock} from './browser-clock.js';
export const FACILITY_DAY = dashboardClock().day;
export const FACILITY_COUNTS = Object.freeze({});
export function createFacilityFixtures({createEmptyFacilities}) {
  return createEmptyFacilities();
}
