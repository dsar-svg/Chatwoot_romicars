import ApiClient from './ApiClient';

class VehiclePriceAPI extends ApiClient {
  constructor() {
    super('vehicle_prices', { accountScoped: true });
  }

  get({ brandId, modelId, search } = {}) {
    const params = new URLSearchParams();
    if (brandId) params.append('brand_id', brandId);
    if (modelId) params.append('model_id', modelId);
    if (search) params.append('search', search);
    const query = params.toString();
    const url = query ? `${this.url}?${query}` : this.url;
    return axios.get(url);
  }

  import(formData) {
    return axios.post(`${this.url}/import`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new VehiclePriceAPI();
