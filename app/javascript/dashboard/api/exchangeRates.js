import ApiClient from './ApiClient';

class ExchangeRateAPI extends ApiClient {
  constructor() {
    super('exchange_rates', { accountScoped: true });
  }

  fetchCurrent() {
    return axios.post(`${this.url}/fetch_current`);
  }
}

export default new ExchangeRateAPI();
