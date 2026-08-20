import ApiClient from './ApiClient';

class BotLogAPI extends ApiClient {
  constructor() {
    super('bot_logs', { accountScoped: true });
  }

  get({ tipoEvento, severidad, days } = {}) {
    const params = new URLSearchParams();
    if (tipoEvento) params.append('tipo_evento', tipoEvento);
    if (severidad) params.append('severidad', severidad);
    if (days) params.append('days', days);
    const query = params.toString();
    const url = query ? `${this.url}?${query}` : this.url;
    return axios.get(url);
  }
}

export default new BotLogAPI();
