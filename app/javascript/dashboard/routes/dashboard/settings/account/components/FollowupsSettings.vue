<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Switch from 'next/switch/Switch.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

// Settings for ConversationFollowupsJob. The switch used to be an environment variable,
// which meant a redeploy to stop a job that writes to customers on its own.
const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

// Same default and cap as the job (ConversationFollowup::SILENCE_BEFORE_FOLLOWUP and
// ConversationFollowupsJob::MAX_SILENCE_HOURS). The job enforces both on its own; these are
// only so the form does not offer a value it would ignore.
const DEFAULT_HOURS = 5;
const MAX_HOURS = 12;

// Shown as placeholders: a blank field means "use this". Must match
// ConversationFollowupsJob::MESSAGES — if they drift, the job still sends its own default,
// but the placeholder would be describing something else.
const DEFAULT_MESSAGES = {
  cotizado: '¿sigues interesado en {repuesto}? Te confirmo disponibilidad 🔧',
  sin_stock: 'todavía no me llega {repuesto}. ¿Te aviso apenas entre?',
  consulta: '¿estabas buscando algún repuesto en particular? Te lo reviso 🔧',
  derivado:
    '¿pudiste escribirnos por WhatsApp? Si prefieres, déjame tu número y te escribimos nosotros 📲',
  generico: '¿sigues necesitando lo que me consultaste? Te lo reviso 🔧',
};
const STAGES = Object.keys(DEFAULT_MESSAGES);

const stageLabels = computed(() => ({
  cotizado: t('GENERAL_SETTINGS.FORM.FOLLOWUPS.MESSAGES.STAGES.COTIZADO'),
  sin_stock: t('GENERAL_SETTINGS.FORM.FOLLOWUPS.MESSAGES.STAGES.SIN_STOCK'),
  consulta: t('GENERAL_SETTINGS.FORM.FOLLOWUPS.MESSAGES.STAGES.CONSULTA'),
  derivado: t('GENERAL_SETTINGS.FORM.FOLLOWUPS.MESSAGES.STAGES.DERIVADO'),
  generico: t('GENERAL_SETTINGS.FORM.FOLLOWUPS.MESSAGES.STAGES.GENERICO'),
}));

const isEnabled = ref(false);
const isToggling = ref(false);
const isSaving = ref(false);
const hours = ref(DEFAULT_HOURS);
const messages = ref(Object.fromEntries(STAGES.map(stage => [stage, ''])));

watch(
  currentAccount,
  account => {
    const settings = account?.settings || {};
    // Stored from a JSON boolean, but compare as text so a string "true" written by hand
    // in a console reads the same way the job's SQL (`settings ->> ...`) reads it.
    isEnabled.value = String(settings.followups_enabled) === 'true';
    hours.value = Number(settings.followups_silence_hours) || DEFAULT_HOURS;
    STAGES.forEach(stage => {
      messages.value[stage] = settings[`followups_message_${stage}`] || '';
    });
  },
  { deep: true, immediate: true }
);

const toggle = async () => {
  isToggling.value = true;
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
    isToggling.value = false;
  }
};

const save = async () => {
  const value = Number(hours.value);
  if (!Number.isInteger(value) || value < 1 || value > MAX_HOURS) {
    useAlert(t('GENERAL_SETTINGS.FORM.FOLLOWUPS.SILENCE.ERROR'));
    return;
  }

  isSaving.value = true;
  try {
    await updateAccount(
      {
        followups_silence_hours: value,
        ...Object.fromEntries(
          STAGES.map(stage => [
            `followups_message_${stage}`,
            messages.value[stage].trim(),
          ])
        ),
      },
      { silent: true }
    );
    useAlert(t('GENERAL_SETTINGS.FORM.FOLLOWUPS.API.SAVED'));
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.FOLLOWUPS.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
  >
    <div class="flex flex-col gap-2 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('GENERAL_SETTINGS.FORM.FOLLOWUPS.TITLE') }}
        </h3>
        <Switch v-model="isEnabled" :disabled="isToggling" @change="toggle" />
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.FOLLOWUPS.NOTE') }}
      </p>
    </div>

    <form v-if="isEnabled" class="grid gap-5 px-5 py-4" @submit.prevent="save">
      <Input
        v-model="hours"
        type="number"
        min="1"
        :max="String(MAX_HOURS)"
        :label="t('GENERAL_SETTINGS.FORM.FOLLOWUPS.SILENCE.LABEL')"
        :message="t('GENERAL_SETTINGS.FORM.FOLLOWUPS.SILENCE.HELP')"
      />

      <div class="grid gap-3">
        <div>
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ t('GENERAL_SETTINGS.FORM.FOLLOWUPS.MESSAGES.LABEL') }}
          </p>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('GENERAL_SETTINGS.FORM.FOLLOWUPS.MESSAGES.HELP') }}
          </p>
        </div>
        <TextArea
          v-for="stage in STAGES"
          :key="stage"
          v-model="messages[stage]"
          :label="stageLabels[stage]"
          :placeholder="DEFAULT_MESSAGES[stage]"
          :max-length="500"
          auto-height
        />
      </div>

      <div class="flex gap-2">
        <NextButton
          blue
          type="submit"
          :is-loading="isSaving"
          :label="t('GENERAL_SETTINGS.FORM.FOLLOWUPS.UPDATE_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
