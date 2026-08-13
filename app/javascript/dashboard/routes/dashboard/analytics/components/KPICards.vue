<script setup>
defineProps({
  kpis: {
    type: Object,
    default: () => ({ total_leads: 0, conversion: 0, active_chats: 0 }),
  },
  loading: { type: Boolean, default: false },
});

const cards = [
  {
    key: 'total_leads',
    label: 'Total Leads',
    icon: 'i-lucide-users',
    format: v => v.toLocaleString(),
    gradient: 'from-blue-500/10 to-blue-500/5 dark:from-blue-500/20 dark:to-blue-500/5',
    iconBg: 'bg-blue-100 dark:bg-blue-500/20',
    iconColor: 'text-blue-600 dark:text-blue-400',
    border: 'group-hover:border-blue-300 dark:group-hover:border-blue-500/40',
  },
  {
    key: 'conversion',
    label: 'Conversión',
    icon: 'i-lucide-trending-up',
    format: v => `${v}%`,
    gradient: 'from-emerald-500/10 to-emerald-500/5 dark:from-emerald-500/20 dark:to-emerald-500/5',
    iconBg: 'bg-emerald-100 dark:bg-emerald-500/20',
    iconColor: 'text-emerald-600 dark:text-emerald-400',
    border: 'group-hover:border-emerald-300 dark:group-hover:border-emerald-500/40',
  },
  {
    key: 'active_chats',
    label: 'Chats Activos',
    icon: 'i-lucide-message-circle',
    format: v => v.toLocaleString(),
    gradient: 'from-amber-500/10 to-amber-500/5 dark:from-amber-500/20 dark:to-amber-500/5',
    iconBg: 'bg-amber-100 dark:bg-amber-500/20',
    iconColor: 'text-amber-600 dark:text-amber-400',
    border: 'group-hover:border-amber-300 dark:group-hover:border-amber-500/40',
  },
];
</script>

<template>
  <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
    <div
      v-for="card in cards"
      :key="card.key"
      class="group relative bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5 overflow-hidden transition-all duration-300 hover:-translate-y-1 hover:shadow-lg"
      :class="card.border"
    >
      <!-- Background gradient -->
      <div
        class="absolute inset-0 bg-gradient-to-br opacity-60 pointer-events-none rounded-xl"
        :class="card.gradient"
      />

      <div class="relative flex items-start justify-between">
        <div>
          <p class="text-[10px] font-semibold uppercase tracking-widest text-n-slate-9 mb-2">
            {{ card.label }}
          </p>
          <div v-if="loading" class="h-8 w-24 bg-n-alpha-2 rounded animate-pulse" />
          <p v-else class="text-3xl font-bold text-n-slate-12 tabular-nums tracking-tight">
            {{ card.format(kpis[card.key] ?? 0) }}
          </p>
        </div>
        <div
          class="flex items-center justify-center size-10 rounded-lg flex-shrink-0"
          :class="card.iconBg"
        >
          <span class="size-5" :class="[card.icon, card.iconColor]" />
        </div>
      </div>

      <p class="relative text-xs text-n-slate-9 mt-3">Últimos 30 días</p>
    </div>
  </div>
</template>
