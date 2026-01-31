/* global axios */

import ApiClient from '../ApiClient';

class TiendaNubeAPI extends ApiClient {
  constructor() {
    super('integrations/tiendanube', { accountScoped: true });
  }

  getOrders(contactId) {
    return axios.get(`${this.url}/orders`, {
      params: { contact_id: contactId },
    });
  }
}

export default new TiendaNubeAPI();
