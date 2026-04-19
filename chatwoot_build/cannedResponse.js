/* global axios */

import ApiClient from './ApiClient';

class CannedResponse extends ApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
  }

  get({ searchKey }) {
    const url = searchKey ? `${this.url}?search=${searchKey}` : this.url;
    return axios.get(url);
  }

  createWithAudio({ shortCode, audioBlob, audioFileName }) {
    const formData = new FormData();
    formData.append('canned_response[short_code]', shortCode);
    formData.append('canned_response[content]', '🎤 Audio response');
    formData.append('canned_response[response_type]', 'audio');
    formData.append('canned_response[personal]', 'true');
    formData.append('canned_response[audio]', audioBlob, audioFileName);
    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  updateWithAudio(id, { shortCode, audioBlob, audioFileName }) {
    const formData = new FormData();
    formData.append('canned_response[short_code]', shortCode);
    formData.append('canned_response[content]', '🎤 Audio response');
    formData.append('canned_response[response_type]', 'audio');
    if (audioBlob) {
      formData.append('canned_response[audio]', audioBlob, audioFileName);
    }
    return axios.put(`${this.url}/${id}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  getAudioUrl(id) {
    return `${this.url}/${id}/audio`;
  }
}

export default new CannedResponse();
