<script setup>
import { computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import Select from 'dashboard/components-next/select/Select.vue';
import { PERIOD_OPTIONS } from '../period';

const filters = defineModel({ type: Object, required: true });

const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');

const CHANNEL_NAMES = {
  'Channel::Whatsapp': 'WhatsApp',
  'Channel::Instagram': 'Instagram',
  'Channel::FacebookPage': 'Facebook',
  'Channel::WebWidget': 'Web',
  'Channel::Email': 'Correo',
};

// One option per kind of channel: the two WhatsApp lines are one "WhatsApp".
const channelOptions = computed(() => {
  const types = [...new Set(inboxes.value.map(inbox => inbox.channel_type))];
  return [
    { value: '', label: 'Todos los canales' },
    ...types.map(type => ({
      value: type,
      label: CHANNEL_NAMES[type] || type.replace('Channel::', ''),
    })),
  ];
});

const agentOptions = computed(() => [
  { value: '', label: 'Todos los vendedores' },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);

const field = key =>
  computed({
    get: () => filters.value[key],
    set: value => {
      filters.value = { ...filters.value, [key]: value };
    },
  });

const preset = field('preset');
const from = field('from');
const to = field('to');
const channel = field('channel');
const agentId = field('agentId');

onMounted(() => store.dispatch('agents/get'));
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <Select v-model="preset" :options="PERIOD_OPTIONS" aria-label="Período" />
    <template v-if="preset === 'custom'">
      <input
        v-model="from"
        type="date"
        aria-label="Desde"
        class="!mb-0 rounded-lg border-0 bg-n-surface-1 px-3 py-2 text-sm outline outline-1 -outline-offset-1 outline-n-weak"
      />
      <input
        v-model="to"
        type="date"
        aria-label="Hasta"
        class="!mb-0 rounded-lg border-0 bg-n-surface-1 px-3 py-2 text-sm outline outline-1 -outline-offset-1 outline-n-weak"
      />
    </template>
    <Select v-model="channel" :options="channelOptions" aria-label="Canal" />
    <Select v-model="agentId" :options="agentOptions" aria-label="Vendedor" />
  </div>
</template>
