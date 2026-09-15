<script setup>
defineProps({
  metrics: {
    type: Object,
    default: () => ({
      new_today: 0,
      pending: 0,
      high_urgency: 0,
      bot: 0,
      agent: 0,
      resolved_today: 0,
    }),
  },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['cardClick']);

// `alert` is the colour a non-zero value takes; zero stays neutral so an idle
// shop does not show amber and red cards for nothing.
const cards = [
  { key: 'new_today', label: 'Nuevos Hoy', icon: 'i-lucide-user-plus' },
  {
    key: 'pending',
    label: 'Pendientes',
    icon: 'i-lucide-clock',
    alert: 'text-n-amber-11',
  },
  {
    key: 'high_urgency',
    label: 'Alta Urgencia',
    icon: 'i-lucide-alert-triangle',
    alert: 'text-n-ruby-11',
  },
  { key: 'bot', label: 'En Bot', icon: 'i-lucide-bot' },
  { key: 'agent', label: 'En Agente', icon: 'i-lucide-user-check' },
  {
    key: 'resolved_today',
    label: 'Resueltos Hoy',
    icon: 'i-lucide-check-circle',
    alert: 'text-n-teal-11',
  },
];

function colorFor(card, metrics) {
  return card.alert && (metrics[card.key] ?? 0) > 0 ? card.alert : '';
}

function handleCardClick(key) {
  emit('cardClick', key);
}
</script>

<template>
  <div class="grid grid-cols-2 sm:grid-cols-6 gap-3">
    <button
      v-for="card in cards"
      :key="card.key"
      type="button"
      class="bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-4 flex flex-col items-start text-left gap-2 transition-colors duration-200 hover:border-n-strong focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      @click="handleCardClick(card.key)"
    >
      <span
        class="size-4"
        :class="[card.icon, colorFor(card, metrics) || 'text-n-blue-11']"
      />
      <div v-if="loading" class="h-7 w-10 bg-n-alpha-2 rounded animate-pulse" />
      <p
        v-else
        class="text-[26px] font-bold tabular-nums leading-none"
        :class="colorFor(card, metrics) || 'text-n-slate-12'"
      >
        {{ metrics[card.key] ?? 0 }}
      </p>
      <p class="text-xs text-n-slate-11 leading-tight">
        {{ card.label }}
      </p>
    </button>
  </div>
</template>
