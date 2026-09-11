// Fixture personas only simulate access. Connected views use capabilities returned
// by the existing RPCs; the server independently authorizes every read/write.
const persona = (id, name, initials, roleLabel, personal, accessible, assigned) => Object.freeze({
  id, name, initials, roleLabel,
  personalHorseIds: Object.freeze(personal),
  accessibleHorseIds: Object.freeze(accessible),
  assignedHorseIds: Object.freeze(assigned),
});

export const PERSONAS = Object.freeze({
  manager: persona('manager', 'Emma de Vries', 'EV', 'Stalmanager', ['orion'], ['orion', 'nova'], ['orion', 'nova']),
  owner: persona('owner', 'Emma de Vries', 'EV', 'Eigenaar', ['orion'], ['orion', 'nova'], ['orion']),
  rider: persona('rider', 'Sophie Bakker', 'SB', 'Ruiter', [], ['nova'], ['nova']),
  groom: persona('groom', 'Noor Meijer', 'NM', 'Groom', [], ['orion'], ['orion']),
});

export const DEFAULT_PERSONA = PERSONAS.manager;
