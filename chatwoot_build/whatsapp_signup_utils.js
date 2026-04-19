// FarolChat WABA-PRO — drop-in replacement of chatwoot's whatsapp/utils.js
// Adds Coex / Cloud API mode selection in initWhatsAppEmbeddedSignup.
import { loadScript } from 'dashboard/helper/DOMHelpers';

export const loadFacebookSdk = async () => {
  return loadScript('https://connect.facebook.net/en_US/sdk.js', {
    async: true,
    defer: true,
    crossOrigin: 'anonymous',
  });
};

export const initializeFacebook = (appId, apiVersion) => {
  const version = apiVersion || 'v25.0';
  return new Promise(resolve => {
    const init = () => {
      window.FB.init({
        appId,
        autoLogAppEvents: true,
        xfbml: true,
        version,
      });
      resolve();
    };

    if (window.FB) {
      init();
    } else {
      window.fbAsyncInit = init;
    }
  });
};

export const isValidBusinessData = businessData => {
  return businessData && businessData.business_id && businessData.waba_id;
};

export const createMessageHandler = onEmbeddedSignupData => {
  return event => {
    if (!event.origin.endsWith('facebook.com')) return;

    try {
      let data;
      if (typeof event.data === 'string') {
        data = JSON.parse(event.data);
      } else if (typeof event.data === 'object' && event.data !== null) {
        data = event.data;
      } else {
        return;
      }

      if (data.type === 'WA_EMBEDDED_SIGNUP') {
        onEmbeddedSignupData(data);
      }
    } catch {
      // Ignore non-JSON or irrelevant messages
    }
  };
};

// WABA-PRO: 2nd arg now accepts options for mode selection.
// mode: 'cloud' (Cloud API only) | 'coex' (Coexistence with WhatsApp Business app)
export const initWhatsAppEmbeddedSignup = (configId, options = {}) => {
  const mode = options.mode || 'cloud';
  const sessionInfoVersion = options.sessionInfoVersion || '3';

  const extras = {
    setup: {},
    sessionInfoVersion,
  };
  // Only set featureType for Coexistence flow.
  // Meta requires the WhatsApp Business app onboarding feature for SMB Coex.
  if (mode === 'coex') {
    extras.featureType = 'whatsapp_business_app_onboarding';
  }

  return new Promise((resolve, reject) => {
    window.FB.login(
      response => {
        if (response.authResponse && response.authResponse.code) {
          resolve(response.authResponse.code);
        } else if (response.error) {
          reject(new Error(response.error));
        } else {
          reject(new Error('Login cancelled'));
        }
      },
      {
        config_id: configId,
        response_type: 'code',
        override_default_response_type: true,
        extras,
      }
    );
  });
};

export const setupFacebookSdk = async (appId, apiVersion) => {
  const version = apiVersion || 'v25.0';
  await loadFacebookSdk();
  await initializeFacebook(appId, version);
};
