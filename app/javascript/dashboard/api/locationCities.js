/* global axios */
import ApiClient from './ApiClient';

class LocationCityAPI extends ApiClient {
  constructor() {
    super('location_cities', { accountScoped: true });
  }

  get({ stateId } = {}) {
    const url = stateId ? `${this.url}?state_id=${stateId}` : this.url;
    return axios.get(url);
  }
}

export default new LocationCityAPI();
