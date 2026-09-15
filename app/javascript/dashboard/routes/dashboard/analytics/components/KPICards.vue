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
    format: v => v.toLocaleString('es-VE'),
    featured: true,
  },
  {
    key: 'conversion',
    label: 'Conversión',
    icon: 'i-lucide-trending-up',
    format: v => `${v}%`,
  },
  {
    key: 'active_chats',
    label: 'Chats Activos',
    icon: 'i-lucide-message-circle',
    format: v => v.toLocaleString('es-VE'),
  },
];
</script>

<template>
  <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
    <div
      v-for="card in cards"
      :key="card.key"
      class="rounded-xl p-5 flex flex-col gap-2.5 transition-colors duration-200"
      :class="
        card.featured
          ? 'bg-n-brand text-white'
          : 'bg-white dark:bg-n-solid-2 border border-n-weak hover:border-n-strong'
      "
    >
      <div class="flex items-center justify-between">
        <p
          class="text-[11px] font-semibold uppercase tracking-widest"
          :class="card.featured ? 'text-white/80' : 'text-n-slate-10'"
        >
          {{ card.label }}
        </p>
        <span
          class="size-[18px]"
          :class="[
            card.icon,
            card.featured ? 'text-white/80' : 'text-n-blue-11',
          ]"
        />
      </div>
      <div
        v-if="loading"
        class="h-10 w-24 rounded animate-pulse"
        :class="card.featured ? 'bg-white/20' : 'bg-n-alpha-2'"
      />
      <p
        v-else
        class="text-4xl font-bold tabular-nums tracking-tight leading-none"
        :class="card.featured ? 'text-white' : 'text-n-slate-12'"
      >
        {{ card.format(kpis[card.key] ?? 0) }}
      </p>
      <p
        class="text-[13px]"
        :class="card.featured ? 'text-white/80' : 'text-n-slate-10'"
      >
        Últimos 30 días
      </p>
    </div>
  </div>
</template>
