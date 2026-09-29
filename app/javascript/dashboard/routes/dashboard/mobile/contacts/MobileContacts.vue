<script setup>
import { ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import ContactAPI from 'dashboard/api/contacts';
import MobileHeader from '../components/MobileHeader.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const MIN_QUERY_LENGTH = 2;

const route = useRoute();
const query = ref('');
const contacts = ref([]);
const isLoading = ref(false);
const hasSearched = ref(false);

// Local results, not the contacts store: the desktop contacts page owns that list.
const search = useDebounceFn(async term => {
  if (term.length < MIN_QUERY_LENGTH) {
    contacts.value = [];
    hasSearched.value = false;
    return;
  }
  isLoading.value = true;
  try {
    const { data } = await ContactAPI.search(term);
    // Drop a slow answer for a query the agent already changed.
    if (term === query.value.trim()) {
      contacts.value = data.payload || [];
      hasSearched.value = true;
    }
  } catch (error) {
    contacts.value = [];
  } finally {
    isLoading.value = false;
  }
}, 300);

watch(query, value => search(value.trim()));
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader :title="$t('MOBILE.CONTACTS.TITLE')" />
    <div class="flex-shrink-0 px-3 py-2 border-b border-n-weak">
      <input
        v-model="query"
        type="search"
        :placeholder="$t('MOBILE.CONTACTS.SEARCH')"
        class="w-full mb-0 text-sm rounded-lg"
      />
    </div>
    <div class="flex flex-col flex-1 min-h-0 overflow-y-auto">
      <router-link
        v-for="contact in contacts"
        :key="contact.id"
        :to="{
          name: 'mobile_contact',
          params: { accountId: route.params.accountId, contactId: contact.id },
        }"
        class="flex items-center gap-3 px-4 py-3 border-b border-n-weak active:bg-n-alpha-2"
      >
        <Avatar
          :name="contact.name || ''"
          :src="contact.thumbnail"
          :size="36"
          rounded-full
        />
        <div class="flex flex-col min-w-0">
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ contact.name }}
          </span>
          <span class="text-xs truncate text-n-slate-11">
            {{ contact.phone_number || contact.email }}
          </span>
        </div>
      </router-link>
      <div class="flex justify-center p-4">
        <Spinner v-if="isLoading" />
        <p
          v-else-if="hasSearched && !contacts.length"
          class="text-sm text-n-slate-11"
        >
          {{ $t('MOBILE.CONTACTS.EMPTY') }}
        </p>
        <p v-else-if="!hasSearched" class="text-sm text-n-slate-11">
          {{ $t('MOBILE.CONTACTS.HINT') }}
        </p>
      </div>
    </div>
  </div>
</template>
