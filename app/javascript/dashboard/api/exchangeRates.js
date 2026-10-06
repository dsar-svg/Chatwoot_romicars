import ApiClient from './ApiClient';

class ExchangeRateAPI extends ApiClient {
  constructor() {
    super('exchange_rates', { accountScoped: true });
  }

  fetchCurrent() {
    return axios.post(`${this.url}/fetch_current`);
  }

  updateMarkup(percent) {
    return axios.patch(`${this.url}/markup`, { percent });
  }
}

export default new ExchangeRateAPI();
