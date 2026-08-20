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

const cards = [
  {
    key: 'new_today',
    label: 'Nuevos Hoy',
    icon: 'i-lucide-user-plus',
    color: 'text-blue-600 dark:text-blue-400',
    bg: 'bg-blue-50 dark:bg-blue-500/10',
  },
  {
    key: 'pending',
    label: 'Pendientes',
    icon: 'i-lucide-clock',
    color: 'text-amber-600 dark:text-amber-400',
    bg: 'bg-amber-50 dark:bg-amber-500/10',
  },
  {
    key: 'high_urgency',
    label: 'Alta Urgencia',
    icon: 'i-lucide-alert-triangle',
    color: 'text-red-600 dark:text-red-400',
    bg: 'bg-red-50 dark:bg-red-500/10',
  },
  {
    key: 'bot',
    label: 'En Bot',
    icon: 'i-lucide-bot',
    color: 'text-violet-600 dark:text-violet-400',
    bg: 'bg-violet-50 dark:bg-violet-500/10',
  },
  {
    key: 'agent',
    label: 'En Agente',
    icon: 'i-lucide-headphones',
    color: 'text-cyan-600 dark:text-cyan-400',
    bg: 'bg-cyan-50 dark:bg-cyan-500/10',
  },
  {
    key: 'resolved_today',
    label: 'Resueltos Hoy',
    icon: 'i-lucide-check-circle',
    color: 'text-emerald-600 dark:text-emerald-400',
    bg: 'bg-emerald-50 dark:bg-emerald-500/10',
  },
];
</script>

<template>
  <div class="grid grid-cols-2 sm:grid-cols-6 gap-3">
    <div
      v-for="card in cards"
      :key="card.key"
      class="bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-4 flex flex-col items-center text-center gap-2"
    >
      <div
        class="flex items-center justify-center size-9 rounded-lg"
        :class="card.bg"
      >
        <span class="size-4" :class="[card.icon, card.color]" />
      </div>
      <div v-if="loading" class="h-7 w-10 bg-n-alpha-2 rounded animate-pulse" />
      <p v-else class="text-2xl font-bold tabular-nums" :class="card.color">
        {{ metrics[card.key] ?? 0 }}
      </p>
      <p class="text-[10px] font-semibold uppercase tracking-wide text-n-slate-9 leading-tight">
        {{ card.label }}
      </p>
    </div>
  </div>
</template>
