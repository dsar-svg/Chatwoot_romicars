import ApiClient from './ApiClient';

class FaqAPI extends ApiClient {
  constructor() {
    super('faqs', { accountScoped: true });
  }

  get({ searchKey, category } = {}) {
    const params = new URLSearchParams();
    if (searchKey) params.append('search', searchKey);
    if (category) params.append('category', category);
    const query = params.toString();
    const url = query ? `${this.url}?${query}` : this.url;
    return axios.get(url);
  }
}

export default new FaqAPI();
