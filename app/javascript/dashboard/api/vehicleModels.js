import ApiClient from './ApiClient';

class VehicleModelAPI extends ApiClient {
  constructor() {
    super('vehicle_models', { accountScoped: true });
  }

  get({ brandId } = {}) {
    const params = brandId ? `?brand_id=${brandId}` : '';
    const url = params ? `${this.url}${params}` : this.url;
    return axios.get(url);
  }
}

export default new VehicleModelAPI();
