<script setup>
const props = defineProps({
  insights: { type: Array, default: () => [] },
  source: { type: String, default: 'rules' },
  loading: { type: Boolean, default: false },
});

const priorityConfig = {
  alta: { label: 'Alta', classes: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' },
  media: { label: 'Media', classes: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' },
  baja: { label: 'Baja', classes: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400' },
};

function priorityCfg(p) {
  return priorityConfig[p] || priorityConfig.baja;
}
</script>

<template>
  <section>
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-2">
        <span class="i-lucide-sparkles size-4 text-[#1A365D] dark:text-blue-11" />
        <h2 class="text-sm font-semibold text-n-slate-12">Insights Estratégicos</h2>
      </div>
      <span
        class="text-[10px] font-medium px-2 py-0.5 rounded-full"
        :class="source === 'ai'
          ? 'bg-[#1A365D]/10 text-[#1A365D] dark:bg-blue-11/10 dark:text-blue-11'
          : 'bg-n-alpha-2 text-n-slate-9'"
      >
        {{ source === 'ai' ? 'GPT-4o-mini' : 'Reglas' }}
      </span>
    </div>

    <!-- Loading skeletons -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div
        v-for="i in 3"
        :key="i"
        class="animate-pulse bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5 h-48"
      >
        <div class="h-3 bg-n-alpha-2 rounded w-1/4 mb-3" />
        <div class="h-4 bg-n-alpha-2 rounded w-3/4 mb-4" />
        <div class="space-y-2">
          <div class="h-3 bg-n-alpha-2 rounded w-full" />
          <div class="h-3 bg-n-alpha-2 rounded w-5/6" />
          <div class="h-3 bg-n-alpha-2 rounded w-4/6" />
        </div>
      </div>
    </div>

    <!-- Insights grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div
        v-for="(insight, idx) in insights"
        :key="idx"
        class="group bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5 flex flex-col gap-3 transition-all duration-300 hover:-translate-y-1 hover:shadow-lg hover:border-[#1A365D]/30 dark:hover:border-blue-11/20"
      >
        <div class="flex items-center justify-between">
          <span class="text-[10px] font-bold text-n-slate-9 tabular-nums">
            {{ String(idx + 1).padStart(2, '0') }}
          </span>
          <span
            class="text-[10px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded-full"
            :class="priorityCfg(insight.priority).classes"
          >
            {{ priorityCfg(insight.priority).label }}
          </span>
        </div>

        <h3 class="text-sm font-semibold text-n-slate-12 leading-snug">
          {{ insight.title }}
        </h3>

        <p class="text-xs text-n-slate-11 leading-relaxed flex-1">
          {{ insight.description }}
        </p>

        <div class="flex items-start gap-1.5 pt-1 border-t border-n-weak">
          <span class="i-lucide-zap size-3.5 text-[#1A365D] dark:text-blue-11 flex-shrink-0 mt-0.5" />
          <p class="text-xs text-[#1A365D] dark:text-blue-11 leading-relaxed">
            {{ insight.action }}
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
