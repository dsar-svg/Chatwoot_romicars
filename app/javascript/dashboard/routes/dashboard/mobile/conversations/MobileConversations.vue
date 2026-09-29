<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import wootConstants from 'dashboard/constants/globals';
import MobileHeader from '../components/MobileHeader.vue';
import MobileConversationItem from '../components/MobileConversationItem.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { ASSIGNEE_TYPE, STATUS_TYPE, SORT_BY_TYPE } = wootConstants;

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const assigneeType = ref(ASSIGNEE_TYPE.ME);
const status = ref(STATUS_TYPE.OPEN);

const assigneeTabs = computed(() => {
  const stats = getters['conversationStats/getStats'].value;
  return [
    {
      key: ASSIGNEE_TYPE.ME,
      label: t('MOBILE.CONVERSATIONS.ASSIGNEE.ME'),
      count: stats.mineCount,
    },
    {
      key: ASSIGNEE_TYPE.UNASSIGNED,
      label: t('MOBILE.CONVERSATIONS.ASSIGNEE.UNASSIGNED'),
      count: stats.unAssignedCount,
    },
    {
      key: ASSIGNEE_TYPE.ALL,
      label: t('MOBILE.CONVERSATIONS.ASSIGNEE.ALL'),
      count: stats.allCount,
    },
  ];
});

const statusOptions = computed(() =>
  ['OPEN', 'PENDING', 'SNOOZED', 'RESOLVED', 'ALL'].map(key => ({
    value: STATUS_TYPE[key],
    label: t(`MOBILE.CONVERSATIONS.STATUS.${key}`),
  }))
);

const currentPage = computed(
  () =>
    getters['conversationPage/getCurrentPageFilter'].value(
      assigneeType.value
    ) || 0
);
const endReached = computed(() =>
  getters['conversationPage/getHasEndReached'].value(assigneeType.value)
);
const isLoading = computed(() => getters.getChatListLoadingStatus.value);

const filters = page => ({
  assigneeType: assigneeType.value,
  status: status.value,
  sortBy: SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC,
  page,
});

const listGetter = {
  [ASSIGNEE_TYPE.ME]: 'getMineChats',
  [ASSIGNEE_TYPE.UNASSIGNED]: 'getUnAssignedChats',
  [ASSIGNEE_TYPE.ALL]: 'getAllStatusChats',
};

const conversations = computed(() => {
  const list = getters[listGetter[assigneeType.value]].value(filters(1));
  return [...list].sort(
    (a, b) => (b.last_activity_at || 0) - (a.last_activity_at || 0)
  );
});

const fetchPage = page => {
  store.dispatch('updateChatListFilters', filters(page));
  return store.dispatch('fetchAllConversations');
};

// Same sequence the desktop list runs when its filters change: drop what is loaded,
// then ask for page 1 and the tab counts.
const reload = () => {
  store.dispatch('conversationPage/reset');
  store.dispatch('emptyAllConversations');
  store.dispatch('setChatListFilters', filters(1));
  store.dispatch('setChatStatusFilter', status.value);
  store.dispatch('conversationStats/get', filters(1));
  fetchPage(1);
};

const loadMore = () => {
  if (endReached.value || isLoading.value) return;
  fetchPage(currentPage.value + 1);
};

watch([assigneeType, status], reload);
onMounted(reload);
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader :title="$t('MOBILE.CONVERSATIONS.TITLE')">
      <template #end>
        <select
          v-model="status"
          :aria-label="$t('MOBILE.CONVERSATIONS.STATUS.LABEL')"
          class="w-auto h-8 py-0 mb-0 text-sm rounded-lg"
        >
          <option
            v-for="option in statusOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </template>
    </MobileHeader>
    <div class="flex flex-shrink-0 gap-1 px-3 py-2 border-b border-n-weak">
      <button
        v-for="tab in assigneeTabs"
        :key="tab.key"
        type="button"
        class="flex items-center justify-center flex-1 gap-1 px-2 py-1.5 text-sm rounded-lg"
        :class="
          assigneeType === tab.key
            ? 'bg-n-brand text-white font-medium'
            : 'bg-n-alpha-2 text-n-slate-11'
        "
        @click="assigneeType = tab.key"
      >
        <span>{{ tab.label }}</span>
        <span class="text-xs opacity-80">{{ tab.count }}</span>
      </button>
    </div>
    <div class="flex flex-col flex-1 min-h-0 overflow-y-auto">
      <MobileConversationItem
        v-for="conversation in conversations"
        :key="conversation.id"
        :conversation="conversation"
      />
      <div class="flex justify-center p-4">
        <Spinner v-if="isLoading" />
        <p
          v-else-if="!conversations.length"
          class="text-sm text-center text-n-slate-11"
        >
          {{ $t('MOBILE.CONVERSATIONS.EMPTY') }}
        </p>
        <p v-else-if="endReached" class="text-xs text-n-slate-10">
          {{ $t('MOBILE.CONVERSATIONS.END') }}
        </p>
        <Button
          v-else
          :label="$t('MOBILE.LOAD_MORE')"
          variant="faded"
          color="slate"
          size="sm"
          @click="loadMore"
        />
      </div>
    </div>
  </div>
</template>
