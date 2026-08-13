import { frontendURL } from '../../../helper/URLHelper';
import Analytics from './Analytics.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/analytics'),
      name: 'romicars_analytics',
      meta: {
        permissions: ['administrator', 'report_manage'],
      },
      component: Analytics,
    },
  ],
};
