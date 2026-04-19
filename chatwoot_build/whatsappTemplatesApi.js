/* global axios */
import ApiClient from './ApiClient';

class WhatsappTemplatesAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  getInboxUrl(inboxId) {
    return `${this.baseUrl()}/inboxes/${inboxId}/whatsapp_templates`;
  }

  getAll(inboxId) {
    return axios.get(this.getInboxUrl(inboxId));
  }

  create(inboxId, templateData) {
    return axios.post(this.getInboxUrl(inboxId), { template: templateData });
  }

  update(inboxId, templateId, templateData) {
    return axios.patch(`${this.getInboxUrl(inboxId)}/${templateId}`, {
      template: templateData,
    });
  }

  delete(inboxId, templateName) {
    return axios.delete(`${this.getInboxUrl(inboxId)}/${templateName}`);
  }
}

export default new WhatsappTemplatesAPI();
