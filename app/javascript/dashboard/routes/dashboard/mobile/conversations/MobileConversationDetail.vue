<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import wootConstants from 'dashboard/constants/globals';
import { findSnoozeTime } from 'dashboard/helper/snoozeHelpers';
import MobileHeader from '../components/MobileHeader.vue';
import MobileSheet from '../components/MobileSheet.vue';
import MobileSheetItem from '../components/MobileSheetItem.vue';
import MessagesView from 'dashboard/components/widgets/conversation/MessagesView.vue';
import ConversationResolutionModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolutionModal.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { STATUS_TYPE, SNOOZE_OPTIONS } = wootConstants;

const route = useRoute();
const router = useRouter();
const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const isLoading = ref(true);
const isSaving = ref(false);
const showActions = ref(false);
const showAgents = ref(false);
const showLabels = ref(false);
const showSnooze = ref(false);
const showResolution = ref(false);
const selectedLabels = ref([]);

const conversationId = computed(() => Number(route.params.conversationId));
const accountId = computed(() => route.params.accountId);
const chat = computed(() => getters.getSelectedChat.value);
const hasChat = computed(() => chat.value?.id === conversationId.value);
const contact = computed(() => chat.value?.meta?.sender || {});
const inbox = computed(() =>
  getters['inboxes/getInbox'].value(chat.value?.inbox_id)
);
const currentUser = computed(() => getters.getCurrentUser.value);
const agents = computed(() => getters['agents/getVerifiedAgents'].value);
const accountLabels = computed(() => getters['labels/getLabels'].value);
const assigneeId = computed(() => chat.value?.meta?.assignee?.id);

const isResolved = computed(() => chat.value?.status === STATUS_TYPE.RESOLVED);
const canSnooze = computed(() => chat.value?.status === STATUS_TYPE.OPEN);

const listRoute = computed(() => ({
  name: 'mobile_conversations',
  params: { accountId: accountId.value },
}));

const snoozeOptions = computed(() =>
  [
    'UNTIL_NEXT_REPLY',
    'AN_HOUR_FROM_NOW',
    'UNTIL_TOMORROW',
    'UNTIL_NEXT_WEEK',
  ].map(key => ({
    key: SNOOZE_OPTIONS[key],
    label: t(`MOBILE.CONVERSATION.SNOOZE_OPTIONS.${key}`),
  }))
);

// Same steps the desktop view takes for a conversation opened by URL: load it
// if the list does not have it, then make it the selected chat so MessagesView
// and the reply box work on it.
const openConversation = async () => {
  isLoading.value = true;
  let conversation = getters.getConversationById.value(conversationId.value);
  if (!conversation) {
    await store.dispatch('getConversation', conversationId.value);
    conversation = getters.getConversationById.value(conversationId.value);
  }
  if (conversation) {
    await store.dispatch('setActiveChat', { data: conversation });
  }
  isLoading.value = false;
};

watch(conversationId, openConversation, { immediate: true });
onBeforeUnmount(() => store.dispatch('clearSelectedState'));

const run = async (action, successKey) => {
  isSaving.value = true;
  try {
    await action();
    if (successKey) useAlert(t(successKey));
  } catch (error) {
    useAlert(t('MOBILE.CONVERSATION.FAILED'));
  } finally {
    isSaving.value = false;
  }
};

const toggleStatus = payload =>
  run(
    () =>
      store.dispatch('toggleStatus', {
        conversationId: conversationId.value,
        ...payload,
      }),
    'CONVERSATION.CHANGE_STATUS'
  );

const reopen = () => toggleStatus({ status: STATUS_TYPE.OPEN });

// ponytail: skips the required-attributes check the desktop resolve runs; add it
// if the account ever marks conversation attributes as required to resolve.
const resolveWithOutcome = outcome => {
  showResolution.value = false;
  toggleStatus({ status: STATUS_TYPE.RESOLVED, ...outcome });
};

const snooze = key => {
  showSnooze.value = false;
  toggleStatus({
    status: STATUS_TYPE.SNOOZED,
    snoozedUntil: findSnoozeTime(key),
  });
};

const assign = agent => {
  showAgents.value = false;
  showActions.value = false;
  run(
    () =>
      store.dispatch('assignAgent', {
        conversationId: conversationId.value,
        agentId: agent ? agent.id : null,
        assigneeType: agent ? 'User' : null,
      }),
    'MOBILE.CONVERSATION.ASSIGNED'
  );
};

const openLabels = () => {
  selectedLabels.value = [...(chat.value?.labels || [])];
  showActions.value = false;
  showLabels.value = true;
};

const toggleLabel = title => {
  const index = selectedLabels.value.indexOf(title);
  if (index > -1) {
    selectedLabels.value.splice(index, 1);
  } else {
    selectedLabels.value.push(title);
  }
};

const saveLabels = () => {
  showLabels.value = false;
  run(
    () =>
      store.dispatch('conversationLabels/update', {
        conversationId: conversationId.value,
        labels: selectedLabels.value,
      }),
    'MOBILE.CONVERSATION.LABELS_SAVED'
  );
};

const sheets = { agents: showAgents, snooze: showSnooze };
const openSheet = name => {
  showActions.value = false;
  sheets[name].value = true;
};

const viewContact = () => {
  showActions.value = false;
  router.push({
    name: 'mobile_contact',
    params: { accountId: accountId.value, contactId: contact.value.id },
  });
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader
      :title="contact.name || ''"
      :subtitle="inbox.name || ''"
      :back-to="listRoute"
    >
      <template #start>
        <Avatar
          v-if="hasChat"
          :name="contact.name || ''"
          :src="contact.thumbnail"
          :size="32"
          rounded-full
        />
      </template>
      <template v-if="hasChat" #end>
        <Button
          v-if="isResolved"
          :label="$t('MOBILE.CONVERSATION.REOPEN')"
          size="sm"
          color="slate"
          :is-loading="isSaving"
          @click="reopen"
        />
        <Button
          v-else
          :label="$t('MOBILE.CONVERSATION.RESOLVE')"
          size="sm"
          color="teal"
          :is-loading="isSaving"
          @click="showResolution = true"
        />
        <Button
          icon="i-lucide-more-vertical"
          variant="ghost"
          color="slate"
          size="sm"
          :aria-label="$t('MOBILE.CONVERSATION.ACTIONS')"
          @click="showActions = true"
        />
      </template>
    </MobileHeader>

    <div v-if="isLoading" class="flex justify-center p-6">
      <Spinner />
    </div>
    <p v-else-if="!hasChat" class="p-6 text-sm text-center text-n-slate-11">
      {{ $t('MOBILE.CONVERSATION.NOT_FOUND') }}
    </p>
    <MessagesView v-else class="flex-1 min-h-0" />

    <MobileSheet
      v-model:show="showActions"
      :title="$t('MOBILE.CONVERSATION.ACTIONS')"
    >
      <MobileSheetItem
        v-if="assigneeId !== currentUser.id"
        :label="$t('MOBILE.CONVERSATION.ASSIGN_TO_ME')"
        icon="i-lucide-user-check"
        @select="assign(currentUser)"
      />
      <MobileSheetItem
        :label="$t('MOBILE.CONVERSATION.ASSIGN')"
        icon="i-lucide-users"
        @select="openSheet('agents')"
      />
      <MobileSheetItem
        :label="$t('MOBILE.CONVERSATION.LABELS')"
        icon="i-lucide-tag"
        @select="openLabels"
      />
      <MobileSheetItem
        v-if="canSnooze"
        :label="$t('MOBILE.CONVERSATION.SNOOZE')"
        icon="i-lucide-alarm-clock"
        @select="openSheet('snooze')"
      />
      <MobileSheetItem
        :label="$t('MOBILE.CONVERSATION.VIEW_CONTACT')"
        icon="i-lucide-contact"
        @select="viewContact"
      />
    </MobileSheet>

    <MobileSheet
      v-model:show="showAgents"
      :title="$t('MOBILE.CONVERSATION.ASSIGN')"
    >
      <MobileSheetItem
        :label="$t('MOBILE.CONVERSATION.UNASSIGN')"
        icon="i-lucide-user-x"
        :active="!assigneeId"
        @select="assign(null)"
      />
      <MobileSheetItem
        v-for="agent in agents"
        :key="agent.id"
        :label="agent.available_name || agent.name"
        :active="agent.id === assigneeId"
        @select="assign(agent)"
      />
    </MobileSheet>

    <MobileSheet
      v-model:show="showLabels"
      :title="$t('MOBILE.CONVERSATION.LABELS')"
    >
      <MobileSheetItem
        v-for="label in accountLabels"
        :key="label.id"
        :label="label.title"
        :active="selectedLabels.includes(label.title)"
        @select="toggleLabel(label.title)"
      />
      <div class="p-4">
        <Button
          :label="$t('MOBILE.CONVERSATION.SAVE')"
          class="w-full"
          @click="saveLabels"
        />
      </div>
    </MobileSheet>

    <MobileSheet
      v-model:show="showSnooze"
      :title="$t('MOBILE.CONVERSATION.SNOOZE')"
    >
      <MobileSheetItem
        v-for="option in snoozeOptions"
        :key="option.key"
        :label="option.label"
        icon="i-lucide-alarm-clock"
        @select="snooze(option.key)"
      />
    </MobileSheet>

    <ConversationResolutionModal
      :show="showResolution"
      @close="showResolution = false"
      @resolve="resolveWithOutcome"
    />
  </div>
</template>
