<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// Works on the store's snake_case conversation, the same object the list and the
// realtime updates keep current.
const props = defineProps({
  conversation: { type: Object, required: true },
});

const route = useRoute();
const getters = useStoreGetters();
const { t } = useI18n();
const { getPlainText } = useMessageFormatter();

const contact = computed(() => props.conversation.meta?.sender || {});
const assignee = computed(() => props.conversation.meta?.assignee);
const inbox = computed(() =>
  getters['inboxes/getInbox'].value(props.conversation.inbox_id)
);
const inboxIcon = computed(() =>
  getInboxIconByType(inbox.value.channel_type, inbox.value.medium, 'fill')
);

const preview = computed(() => {
  const message = props.conversation.last_non_activity_message;
  return getPlainText(message?.content || t('CHAT_LIST.NO_CONTENT'));
});

const time = computed(() => {
  const { timestamp } = props.conversation;
  return timestamp ? shortTimestamp(dynamicTime(timestamp)) : '';
});

const unread = computed(() => props.conversation.unread_count || 0);
</script>

<template>
  <router-link
    :to="{
      name: 'mobile_conversation',
      params: {
        accountId: route.params.accountId,
        conversationId: conversation.id,
      },
    }"
    class="flex w-full gap-3 px-4 py-3 border-b border-n-weak active:bg-n-alpha-2"
  >
    <Avatar
      :name="contact.name || ''"
      :src="contact.thumbnail"
      :size="40"
      rounded-full
    />
    <div class="flex flex-col flex-1 min-w-0 gap-0.5">
      <div class="flex items-center gap-2">
        <span class="flex-1 text-sm font-medium truncate text-n-slate-12">
          {{ contact.name }}
        </span>
        <Icon
          v-if="inboxIcon"
          :icon="inboxIcon"
          class="flex-shrink-0 size-3.5 text-n-slate-10"
        />
        <span class="flex-shrink-0 text-xs text-n-slate-10">{{ time }}</span>
      </div>
      <div class="flex items-center gap-2">
        <p
          class="flex-1 mb-0 text-sm truncate"
          :class="unread ? 'text-n-slate-12 font-medium' : 'text-n-slate-11'"
        >
          {{ preview }}
        </p>
        <span
          v-if="unread"
          class="flex-shrink-0 min-w-5 h-5 px-1.5 rounded-full bg-n-brand text-white text-xs leading-5 text-center"
        >
          {{ unread > 9 ? '9+' : unread }}
        </span>
      </div>
      <span v-if="assignee" class="text-xs truncate text-n-slate-10">
        {{
          $t('MOBILE.CONVERSATION.ASSIGNED_TO', {
            name: assignee.available_name || assignee.name,
          })
        }}
      </span>
    </div>
  </router-link>
</template>
