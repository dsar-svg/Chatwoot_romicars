import { frontendURL } from '../../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import SettingsWrapper from '../SettingsWrapper.vue';
import BrandsIndex from './Index.vue';
import ModelsIndex from './Models/Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/vehicles'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'vehicle_brands_list', params: to.params };
          },
        },
        {
          path: 'brands',
          name: 'vehicle_brands_list',
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
          component: BrandsIndex,
        },
        {
          path: 'brands/:brandId/models',
          name: 'vehicle_models_list',
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
          component: ModelsIndex,
        },
      ],
    },
  ],
};
