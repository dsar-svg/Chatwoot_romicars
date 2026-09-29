<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import ContactAPI from 'dashboard/api/contacts';
import MobileHeader from '../components/MobileHeader.vue';
import MobileConversationItem from '../components/MobileConversationItem.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const contact = ref(null);
const conversations = ref([]);
const isLoading = ref(true);

const contactId = computed(() => route.params.contactId);
const listRoute = computed(() => ({
  name: 'mobile_contacts',
  params: { accountId: route.params.accountId },
}));

const phoneDigits = computed(() =>
  (contact.value?.phone_number || '').replace(/\D/g, '')
);

const load = async () => {
  isLoading.value = true;
  try {
    const [contactResponse, conversationsResponse] = await Promise.all([
      ContactAPI.show(contactId.value),
      ContactAPI.getConversations(contactId.value),
    ]);
    contact.value = contactResponse.data.payload;
    conversations.value = [...(conversationsResponse.data.payload || [])].sort(
      (a, b) => (b.last_activity_at || 0) - (a.last_activity_at || 0)
    );
  } catch (error) {
    contact.value = null;
  } finally {
    isLoading.value = false;
  }
};

watch(contactId, load, { immediate: true });
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader
      :title="contact?.name || $t('MOBILE.CONTACTS.TITLE')"
      :back-to="listRoute"
    />
    <div v-if="isLoading" class="flex justify-center p-6">
      <Spinner />
    </div>
    <p v-else-if="!contact" class="p-6 text-sm text-center text-n-slate-11">
      {{ $t('MOBILE.CONTACTS.NOT_FOUND') }}
    </p>
    <div v-else class="flex flex-col flex-1 min-h-0 overflow-y-auto">
      <div class="flex flex-col items-center gap-2 px-4 py-5">
        <Avatar
          :name="contact.name || ''"
          :src="contact.thumbnail"
          :size="64"
          rounded-full
        />
        <span class="text-base font-medium text-n-slate-12">
          {{ contact.name }}
        </span>
        <span class="text-sm text-n-slate-11">
          {{
            [contact.phone_number, contact.additional_attributes?.city]
              .filter(Boolean)
              .join(' · ')
          }}
        </span>
        <div v-if="phoneDigits" class="flex gap-2 pt-1">
          <a
            :href="`tel:+${phoneDigits}`"
            class="flex items-center gap-1.5 px-3 h-8 text-sm rounded-lg bg-n-alpha-2 text-n-slate-12"
          >
            <Icon icon="i-lucide-phone" class="size-4" />
            {{ $t('MOBILE.CONTACTS.CALL') }}
          </a>
          <a
            :href="`https://wa.me/${phoneDigits}`"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-1.5 px-3 h-8 text-sm rounded-lg bg-n-teal-3 text-n-teal-11"
          >
            <Icon icon="i-lucide-message-circle" class="size-4" />
            {{ $t('MOBILE.CONTACTS.WHATSAPP') }}
          </a>
        </div>
      </div>
      <h2 class="px-4 pt-2 pb-1 text-xs font-medium uppercase text-n-slate-11">
        {{ $t('MOBILE.CONTACTS.CONVERSATIONS') }}
      </h2>
      <MobileConversationItem
        v-for="conversation in conversations"
        :key="conversation.id"
        :conversation="conversation"
      />
      <p v-if="!conversations.length" class="px-4 py-3 text-sm text-n-slate-11">
        {{ $t('MOBILE.CONTACTS.NO_CONVERSATIONS') }}
      </p>
    </div>
  </div>
</template>
