import ApiClient from './ApiClient';

class LocationStateAPI extends ApiClient {
  constructor() {
    super('location_states', { accountScoped: true });
  }
}

export default new LocationStateAPI();
