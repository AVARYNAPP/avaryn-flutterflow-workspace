// An unauthenticated production view has no fixture identity or permissions.
export const PERSONAS = Object.freeze({});
export const DEFAULT_PERSONA = Object.freeze({
  id: '', name: '', initials: '', roleLabel: '',
  personalHorseIds: Object.freeze([]), accessibleHorseIds: Object.freeze([]),
  assignedHorseIds: Object.freeze([]),
});
