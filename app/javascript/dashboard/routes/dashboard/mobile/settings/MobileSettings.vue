<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import Auth from 'dashboard/api/auth';
import MobileHeader from '../components/MobileHeader.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const route = useRoute();
const accountId = computed(() => route.params.accountId);

const links = computed(() => [
  {
    key: 'brands',
    label: 'MOBILE.SETTINGS.BRANDS',
    icon: 'i-lucide-car',
    to: { name: 'mobile_brands', params: { accountId: accountId.value } },
  },
  {
    key: 'prices',
    label: 'MOBILE.SETTINGS.PRICES',
    icon: 'i-lucide-tags',
    to: { name: 'mobile_prices', params: { accountId: accountId.value } },
  },
]);

// In-app navigation, not a page load, so the installed app does not bounce it
// back to the mobile screens.
const fullVersionRoute = computed(() => ({
  name: 'home',
  params: { accountId: accountId.value },
}));
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader :title="$t('MOBILE.SETTINGS.TITLE')" />
    <div class="flex flex-col flex-1 min-h-0 overflow-y-auto">
      <router-link
        v-for="link in links"
        :key="link.key"
        :to="link.to"
        class="flex items-center gap-3 px-4 py-4 text-sm border-b border-n-weak text-n-slate-12 active:bg-n-alpha-2"
      >
        <Icon :icon="link.icon" class="size-5 text-n-slate-11" />
        <span class="flex-1">{{ $t(link.label) }}</span>
        <Icon icon="i-lucide-chevron-right" class="size-4 text-n-slate-10" />
      </router-link>
      <router-link
        :to="fullVersionRoute"
        class="flex items-center gap-3 px-4 py-4 mt-6 text-sm border-y border-n-weak text-n-slate-12 active:bg-n-alpha-2"
      >
        <Icon icon="i-lucide-monitor" class="size-5 text-n-slate-11" />
        <span class="flex-1">{{ $t('MOBILE.SETTINGS.FULL_VERSION') }}</span>
      </router-link>
      <button
        type="button"
        class="flex items-center gap-3 px-4 py-4 text-sm border-b border-n-weak text-n-ruby-11 active:bg-n-alpha-2"
        @click="Auth.logout()"
      >
        <Icon icon="i-lucide-log-out" class="size-5" />
        <span class="flex-1 text-start">{{
          $t('MOBILE.SETTINGS.LOGOUT')
        }}</span>
      </button>
    </div>
  </div>
</template>
