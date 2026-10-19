/* global axios */
import ApiClient from './ApiClient';

// `params` on the Operación calls: since / until (ISO times), inbox_ids[] and agent_id.
class RomicarsDashboardAPI extends ApiClient {
  constructor() {
    super('romicars_analytics', { accountScoped: true, apiVersion: 'v2' });
  }

  getOverview(params = {}) {
    return axios.get(`${this.url}/overview`, { params });
  }

  getAgents(params = {}) {
    return axios.get(`${this.url}/agents`, { params });
  }

  getDemand(params = {}) {
    return axios.get(`${this.url}/demand`, { params });
  }

  getContactLocations(params = {}) {
    return axios.get(`${this.url}/contact_locations`, { params });
  }

  getCityContacts(labels, params = {}) {
    return axios.get(`${this.url}/city_contacts`, {
      params: { ...params, labels },
    });
  }

  // `refresh` skips the server cache and asks the model again.
  getAIInsights({ refresh = false } = {}) {
    return axios.get(`${this.url}/ai_insights`, {
      params: refresh ? { refresh: 1 } : {},
    });
  }

  getProfit() {
    return axios.get(`${this.url}/profit`);
  }

  getResolution(params = {}) {
    return axios.get(`${this.url}/resolution`, { params });
  }

  getRequestedProducts() {
    return axios.get(`${this.url}/requested_products`);
  }

  getWinLoss({ refresh = false } = {}) {
    return axios.get(`${this.url}/win_loss`, {
      params: refresh ? { refresh: 1 } : {},
    });
  }

  getMiniMetricsDetail(type, params = {}) {
    return axios.get(`${this.url}/mini_metrics_detail`, {
      params: { ...params, type },
    });
  }
}

export default new RomicarsDashboardAPI();
