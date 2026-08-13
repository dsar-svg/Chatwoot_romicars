/* global axios */
import ApiClient from './ApiClient';

class RomicarsDashboardAPI extends ApiClient {
  constructor() {
    super('romicars_analytics', { accountScoped: true, apiVersion: 'v2' });
  }

  getOverview() {
    return axios.get(`${this.url}/overview`);
  }

  getAgents() {
    return axios.get(`${this.url}/agents`);
  }

  getDemand() {
    return axios.get(`${this.url}/demand`);
  }

  getAIInsights() {
    return axios.get(`${this.url}/ai_insights`);
  }

  getProfit() {
    return axios.get(`${this.url}/profit`);
  }
}

export default new RomicarsDashboardAPI();
