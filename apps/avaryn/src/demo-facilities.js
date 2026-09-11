// Explicit demo-only seeds. The production build never imports this module.
export const FACILITY_DAY = '2026-09-10';
export const FACILITY_COUNTS = Object.freeze({stall:10,pasture:4,paddock:2,arena:2,walker:1,wash:2,locker:10});
export function createFacilityFixtures({FACILITY_KINDS, newResource}) {
  const resources = Object.entries(FACILITY_KINDS).flatMap(([kind, meta]) => Array.from({ length: meta.count }, (_, i) => newResource(kind, i + 1)));
  Object.assign(resources.find(row => row.id === 'pasture-1'), { description: 'Aan de kant van de grote eik.' });
  Object.assign(resources.find(row => row.id === 'pasture-2'), { status: 'rest', description: 'Het gras krijgt even rust.' });
  Object.assign(resources.find(row => row.id === 'stall-6'), { type: 'Met uitloop' });
  Object.assign(resources.find(row => row.id === 'arena-1'), { name: 'Binnenbak', type: 'Binnenbak', capacity: 4, description: 'Samen trainen met voldoende ruimte.' });
  Object.assign(resources.find(row => row.id === 'arena-2'), { name: 'Buitenbak', type: 'Buitenbak', capacity: 6, description: 'Frisse lucht en een ruime piste.' });
  return { schema: 1, arenaSetupVersion: 1, tackRoom: true, resources,
    placements: [
      { resourceId: 'stall-4', horseId: 'orion', note: 'Halster hangt naast de staldeur.' },
      { resourceId: 'stall-6', horseId: 'nova', note: '' },
    ],
    arenaBookings: [
      { id: 'arena-orion-morning', resourceId: 'arena-1', date: FACILITY_DAY, start: '09:00', end: '09:45', horseId: 'orion', participants: 1, activity: 'Dressuurtraining', note: 'Een rustige training voor de afspraak op stal.', exclusive: false, status: 'approved', requesterId: 'owner', requesterName: 'Emma de Vries', decisionNote: '' },
      { id: 'arena-nova-lesson', resourceId: 'arena-2', date: FACILITY_DAY, start: '14:00', end: '14:45', horseId: 'nova', participants: 1, activity: 'Springles', note: 'Springles met Sophie.', exclusive: false, status: 'approved', requesterId: 'rider', requesterName: 'Sophie Bakker', decisionNote: '' },
      { id: 'arena-private-request', resourceId: 'arena-2', date: FACILITY_DAY, start: '11:00', end: '11:45', horseId: 'nova', participants: 1, activity: 'Training', note: 'Ik wil de nieuwe oefeningen in alle rust voorbereiden.', exclusive: true, status: 'requested', requesterId: 'rider', requesterName: 'Sophie Bakker', decisionNote: '' },
    ],
    bookings: [
      { id: 'pasture-morning', resourceId: 'pasture-1', horseIds: ['orion', 'nova'], date: FACILITY_DAY, start: '08:00', end: '12:00', note: 'Samen naar buiten. Sluit het hek en controleer de drinkbak.' },
      { id: 'walker-nova', resourceId: 'walker-1', horseIds: ['nova'], date: FACILITY_DAY, start: '09:00', end: '09:30', note: 'Haal Nova op bij Weide 1 en breng haar na afloop terug.' },
      { id: 'wash-orion', resourceId: 'wash-1', horseIds: ['orion'], date: FACILITY_DAY, start: '11:30', end: '12:00', note: 'Zet de poetsplek na afloop weer netjes klaar.' },
      { id: 'paddock-nova', resourceId: 'paddock-1', horseIds: ['nova'], date: FACILITY_DAY, start: '16:00', end: '17:00', note: 'Het halster hangt bij Stal 6.' },
    ],
  };
}
