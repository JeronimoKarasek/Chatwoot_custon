/* global axios */

class EvolutionAPI {
  static async logout(apiUrl, adminToken, instanceName) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/instance/logout/${instanceName}`;

    try {
      const response = await axios.delete(url, {
        headers: {
          apikey: adminToken,
          'Content-Type': 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(error.response.data.message || 'Logout failed');
      }
      throw new Error('Network error during logout');
    }
  }

  static async fetchInstances(apiUrl, adminToken) {
    if (!apiUrl || !adminToken) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/instance/fetchInstances`;

    try {
      const response = await axios.get(url, {
        headers: {
          apikey: adminToken,
          'Content-Type': 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to fetch instances'
        );
      }
      throw new Error('Network error while fetching instances');
    }
  }

  static async getQRCode(apiUrl, adminToken, instanceName) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/instance/connect/${instanceName}`;

    try {
      const response = await axios.get(url, {
        headers: {
          apikey: adminToken,
          'Content-Type': 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(error.response.data.message || 'Failed to get QR code');
      }
      throw new Error('Network error while getting QR code');
    }
  }

  static async findSettings(apiUrl, adminToken, instanceName) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/settings/find/${instanceName}`;

    try {
      const response = await axios.get(url, {
        headers: {
          apikey: adminToken,
          'Content-Type': 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to fetch settings'
        );
      }
      throw new Error('Network error while fetching settings');
    }
  }

  static async setSettings(apiUrl, adminToken, instanceName, settings) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/settings/set/${instanceName}`;

    try {
      const response = await axios.post(url, settings, {
        headers: {
          apikey: adminToken,
          'Content-Type': 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to update settings'
        );
      }
      throw new Error('Network error while updating settings');
    }
  }

  // ===== Profile Management Methods =====

  static async fetchProfile(apiUrl, adminToken, instanceName) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/chat/fetchProfile/${instanceName}`;

    try {
      const response = await axios.get(url, {
        headers: {
          apikey: adminToken,
          'Content-Type': 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to fetch profile'
        );
      }
      throw new Error('Network error while fetching profile');
    }
  }

  static async updateProfileName(apiUrl, adminToken, instanceName, name) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/chat/updateProfileName/${instanceName}`;

    try {
      const response = await axios.post(
        url,
        { name },
        {
          headers: {
            apikey: adminToken,
            'Content-Type': 'application/json',
          },
        }
      );

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to update profile name'
        );
      }
      throw new Error('Network error while updating profile name');
    }
  }

  static async updateProfileStatus(apiUrl, adminToken, instanceName, status) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/chat/updateProfileStatus/${instanceName}`;

    try {
      const response = await axios.post(
        url,
        { status },
        {
          headers: {
            apikey: adminToken,
            'Content-Type': 'application/json',
          },
        }
      );

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to update profile status'
        );
      }
      throw new Error('Network error while updating profile status');
    }
  }

  static async updateProfilePicture(apiUrl, adminToken, instanceName, pictureUrl) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/chat/updateProfilePicture/${instanceName}`;

    try {
      const response = await axios.post(
        url,
        { picture: pictureUrl },
        {
          headers: {
            apikey: adminToken,
            'Content-Type': 'application/json',
          },
        }
      );

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to update profile picture'
        );
      }
      throw new Error('Network error while updating profile picture');
    }
  }

  static async removeProfilePicture(apiUrl, adminToken, instanceName) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/chat/removeProfilePicture/${instanceName}`;

    try {
      const response = await axios.delete(url, {
        headers: {
          apikey: adminToken,
          'Content-Type': 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          error.response.data.message || 'Failed to remove profile picture'
        );
      }
      throw new Error('Network error while removing profile picture');
    }
  }

  static async fetchProfilePicture(apiUrl, adminToken, instanceName) {
    if (!apiUrl || !adminToken || !instanceName) {
      return Promise.reject(new Error('Missing Evolution credentials'));
    }
    const url = `${apiUrl.replace(/\/$/, '')}/chat/fetchProfilePictureUrl/${instanceName}`;

    try {
      const response = await axios.post(
        url,
        { number: instanceName },
        {
          headers: {
            apikey: adminToken,
            'Content-Type': 'application/json',
          },
        }
      );

      return response.data?.profilePictureUrl || response.data?.picture || null;
    } catch (error) {
      // Profile picture might not exist, return null silently
      return null;
    }
  }
}

export default EvolutionAPI;
