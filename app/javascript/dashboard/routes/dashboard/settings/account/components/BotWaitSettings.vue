<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

// Read by Conversations::BotTakeoverJob through Account#bot_wait_minutes, which applies the
// same default and cap on its own; these only keep the form from offering a value it ignores.
const DEFAULT_MINUTES = 20;
const MAX_MINUTES = 120;

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

const minutes = ref(DEFAULT_MINUTES);
const isSaving = ref(false);

watch(
  currentAccount,
  account => {
    minutes.value =
      Number(account?.settings?.bot_wait_minutes) || DEFAULT_MINUTES;
  },
  { deep: true, immediate: true }
);

const save = async () => {
  const value = Number(minutes.value);
  if (!Number.isInteger(value) || value < 1 || value > MAX_MINUTES) {
    useAlert(t('GENERAL_SETTINGS.FORM.BOT_WAIT.ERROR'));
    return;
  }

  isSaving.value = true;
  try {
    await updateAccount({ bot_wait_minutes: value }, { silent: true });
    useAlert(t('GENERAL_SETTINGS.FORM.BOT_WAIT.SAVED'));
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.FOLLOWUPS.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <form
    class="flex flex-col gap-4 w-full px-5 py-4 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
    @submit.prevent="save"
  >
    <div class="flex flex-col gap-2">
      <h3 class="text-heading-2 text-n-slate-12">
        {{ t('GENERAL_SETTINGS.FORM.BOT_WAIT.TITLE') }}
      </h3>
      <p class="mb-0 text-body-para text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.BOT_WAIT.NOTE') }}
      </p>
    </div>
    <Input
      v-model="minutes"
      type="number"
      min="1"
      :max="String(MAX_MINUTES)"
      :label="t('GENERAL_SETTINGS.FORM.BOT_WAIT.LABEL')"
      :message="t('GENERAL_SETTINGS.FORM.BOT_WAIT.HELP')"
    />
    <div class="flex gap-2">
      <NextButton
        blue
        type="submit"
        :is-loading="isSaving"
        :label="t('GENERAL_SETTINGS.FORM.FOLLOWUPS.UPDATE_BUTTON')"
      />
    </div>
  </form>
</template>
