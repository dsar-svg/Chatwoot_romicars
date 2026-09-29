import { frontendURL } from '../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
  CONTACT_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

import MobileLayout from './MobileLayout.vue';
import MobileConversations from './conversations/MobileConversations.vue';
import MobileConversationDetail from './conversations/MobileConversationDetail.vue';
import MobileContacts from './contacts/MobileContacts.vue';
import MobileContactDetail from './contacts/MobileContactDetail.vue';
import MobileSettings from './settings/MobileSettings.vue';
import MobileBrands from './settings/MobileBrands.vue';
import MobileModels from './settings/MobileModels.vue';
import MobilePrices from './settings/MobilePrices.vue';

const conversationPermissions = [...ROLES, ...CONVERSATION_PERMISSIONS];

// The installed app starts at /app/m (manifest start_url). The router guard in
// routes/index.js sends it to the user's account, like it does for /app.
export const MOBILE_ENTRY_ROUTE = 'mobile_entry';

export const routes = [
  {
    path: frontendURL('m'),
    name: MOBILE_ENTRY_ROUTE,
    component: MobileLayout,
  },
  {
    path: frontendURL('accounts/:accountId/m'),
    component: MobileLayout,
    children: [
      {
        path: '',
        redirect: to => ({ name: 'mobile_conversations', params: to.params }),
      },
      {
        path: 'conversations',
        name: 'mobile_conversations',
        meta: { permissions: conversationPermissions },
        component: MobileConversations,
      },
      {
        path: 'conversations/:conversationId',
        name: 'mobile_conversation',
        meta: { permissions: conversationPermissions, hideTabs: true },
        component: MobileConversationDetail,
      },
      {
        path: 'contacts',
        name: 'mobile_contacts',
        meta: { permissions: [...ROLES, CONTACT_PERMISSIONS] },
        component: MobileContacts,
      },
      {
        path: 'contacts/:contactId',
        name: 'mobile_contact',
        meta: { permissions: [...ROLES, CONTACT_PERMISSIONS] },
        component: MobileContactDetail,
      },
      {
        path: 'settings',
        name: 'mobile_settings',
        meta: { permissions: conversationPermissions },
        component: MobileSettings,
      },
      {
        path: 'settings/brands',
        name: 'mobile_brands',
        meta: { permissions: conversationPermissions },
        component: MobileBrands,
      },
      {
        path: 'settings/brands/:brandId/models',
        name: 'mobile_models',
        meta: { permissions: conversationPermissions },
        component: MobileModels,
      },
      {
        path: 'settings/prices',
        name: 'mobile_prices',
        meta: { permissions: conversationPermissions },
        component: MobilePrices,
      },
    ],
  },
];
