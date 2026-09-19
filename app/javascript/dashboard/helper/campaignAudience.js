// The campaign `audience` column is a flat list of typed selectors. Selectors sharing a
// type are ORed by the backend (Chery or Toyota) and the types are ANDed with each other
// (a Chery AND living in Valencia) — see Campaigns::AudienceResolver.
//
// Every selector travels by id so that renaming a brand or a city does not silently
// empty a campaign that was already scheduled.

// A factory, not a constant: TagMultiSelectComboBox pushes into the array it is handed,
// so every form needs arrays of its own.
export const emptyAudienceSelection = () => ({
  labels: [],
  brands: [],
  models: [],
  states: [],
  cities: [],
});

export const buildCampaignAudience = ({
  labels = [],
  brands = [],
  models = [],
  states = [],
  cities = [],
} = {}) => [
  ...labels.map(id => ({ id, type: 'Label' })),
  ...brands.map(id => ({ id, type: 'VehicleBrand' })),
  ...models.map(id => ({ id, type: 'VehicleModel' })),
  ...states.map(id => ({ id, type: 'LocationState' })),
  ...cities.map(id => ({ id, type: 'LocationCity' })),
];

export const hasAudienceSelection = (selection = {}) =>
  buildCampaignAudience(selection).length > 0;
