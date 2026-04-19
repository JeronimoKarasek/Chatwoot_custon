/* global axios */
import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  importCsv(campaignId, file) {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('mass_action', 'import_csv');
    return axios.patch(`${this.url}/${campaignId}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  execute(campaignId) {
    return axios.patch(`${this.url}/${campaignId}`, {
      mass_action: 'execute',
    });
  }

  getProgress(campaignId) {
    return axios.get(`${this.url}/${campaignId}?mass_action=progress`);
  }

  getReport(campaignId) {
    return axios.get(`${this.url}/${campaignId}?mass_action=report`);
  }
}

export default new CampaignsAPI();
