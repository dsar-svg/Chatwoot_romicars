<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Switch from 'next/switch/Switch.vue';

// The only switch for ConversationFollowupsJob. It used to be an environment variable,
// which meant a redeploy to stop a job that writes to customers on its own.
const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

const isEnabled = ref(false);
const isSaving = ref(false);

watch(
  currentAccount,
  account => {
    // Stored from a JSON boolean, but compare as text so a string "true" written by hand
    // in a console reads the same way the job's SQL (`settings ->> ...`) reads it.
    isEnabled.value = String(account?.settings?.followups_enabled) === 'true';
  },
  { deep: true, immediate: true }
);

const toggle = async () => {
  isSaving.value = true;
  try {
    await updateAccount(
      { followups_enabled: isEnabled.value },
      { silent: true }
    );
    useAlert(
      isEnabled.value
        ? t('GENERAL_SETTINGS.FORM.FOLLOWUPS.API.ENABLED')
        : t('GENERAL_SETTINGS.FORM.FOLLOWUPS.API.DISABLED')
    );
  } catch {
    // The switch must never show a state the job is not in.
    isEnabled.value = !isEnabled.value;
    useAlert(t('GENERAL_SETTINGS.FORM.FOLLOWUPS.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <div class="flex flex-col gap-2 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('GENERAL_SETTINGS.FORM.FOLLOWUPS.TITLE') }}
        </h3>
        <Switch v-model="isEnabled" :disabled="isSaving" @change="toggle" />
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.FOLLOWUPS.NOTE') }}
      </p>
    </div>
  </div>
</template>
