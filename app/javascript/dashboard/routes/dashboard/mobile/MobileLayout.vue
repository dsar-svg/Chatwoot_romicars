<script setup>
import { computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { DASHBOARD_PERMISSIONS } from '../analytics/analytics.routes';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const route = useRoute();
const store = useStore();
const { t } = useI18n();
const { checkPermissions } = usePolicy();

// The desktop sidebar loads these on boot; the mobile app lives outside it.
onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('labels/get');
  store.dispatch('agents/get');
  store.dispatch('attributes/get');
});

const tabs = computed(() =>
  [
    {
      name: 'mobile_conversations',
      label: t('MOBILE.TABS.CONVERSATIONS'),
      icon: 'i-lucide-message-circle',
    },
    {
      name: 'mobile_contacts',
      label: t('MOBILE.TABS.CONTACTS'),
      icon: 'i-lucide-contact',
    },
    {
      name: 'mobile_dashboard',
      label: t('MOBILE.TABS.DASHBOARD'),
      icon: 'i-lucide-layout-dashboard',
      permissions: DASHBOARD_PERMISSIONS,
    },
    {
      name: 'mobile_settings',
      label: t('MOBILE.TABS.SETTINGS'),
      icon: 'i-lucide-settings',
    },
  ].filter(tab => checkPermissions(tab.permissions))
);

const activeTab = computed(() => {
  const name = String(route.name || '');
  if (name.startsWith('mobile_conversation')) return 'mobile_conversations';
  if (name.startsWith('mobile_contact')) return 'mobile_contacts';
  if (name === 'mobile_dashboard') return name;
  return 'mobile_settings';
});
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 bg-n-background">
    <main class="flex flex-col flex-1 min-h-0">
      <router-view />
    </main>
    <nav
      v-if="!route.meta.hideTabs"
      class="flex flex-shrink-0 border-t border-n-weak bg-n-solid-1 pb-[env(safe-area-inset-bottom)]"
    >
      <router-link
        v-for="tab in tabs"
        :key="tab.name"
        :to="{ name: tab.name, params: { accountId: route.params.accountId } }"
        class="flex flex-col items-center justify-center flex-1 gap-1 py-2 text-xs"
        :class="
          activeTab === tab.name
            ? 'text-n-brand font-medium'
            : 'text-n-slate-11'
        "
      >
        <Icon :icon="tab.icon" class="size-5" />
        <span>{{ tab.label }}</span>
      </router-link>
    </nav>
  </div>
</template>
