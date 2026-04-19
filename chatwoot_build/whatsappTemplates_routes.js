import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import WhatsappTemplatesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL(
        'accounts/:accountId/settings/whatsapp-templates'
      ),
      component: SettingsWrapper,
      props: { keepAlive: false },
      children: [
        {
          path: '',
          redirect: to => {
            return {
              name: 'whatsapp_templates_list',
              params: to.params,
            };
          },
        },
        {
          path: 'list',
          name: 'whatsapp_templates_list',
          meta: {
            permissions: ['administrator'],
          },
          component: WhatsappTemplatesIndex,
        },
      ],
    },
  ],
};
