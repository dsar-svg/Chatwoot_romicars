import ApiClient from './ApiClient';

class VehicleBrandAPI extends ApiClient {
  constructor() {
    super('vehicle_brands', { accountScoped: true });
  }

  getModels(brandId) {
    return axios.get(`${this.url}/${brandId}/vehicle_models`);
  }
}

export default new VehicleBrandAPI();
