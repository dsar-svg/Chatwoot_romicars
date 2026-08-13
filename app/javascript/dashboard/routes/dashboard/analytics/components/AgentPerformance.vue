<script setup>
defineProps({
  agents: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

function badgeClass(conversion) {
  if (conversion >= 20) return 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400';
  if (conversion >= 10) return 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400';
  return 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400';
}

function avatarGradient(name) {
  const hue = (name.charCodeAt(0) * 37 + name.charCodeAt(1 % name.length) * 17) % 360;
  return `background: linear-gradient(135deg, hsl(${hue},60%,40%), hsl(${(hue + 40) % 360},60%,30%))`;
}

function initials(name) {
  return name
    .split(' ')
    .slice(0, 2)
    .map(w => w[0])
    .join('')
    .toUpperCase();
}

function formatMinutes(mins) {
  if (!mins || mins === 0) return '—';
  if (mins < 60) return `${mins}m`;
  return `${Math.floor(mins / 60)}h ${mins % 60}m`;
}
</script>

<template>
  <div class="bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5">
    <div class="flex items-center gap-2 mb-5">
      <span class="i-lucide-trophy size-4 text-amber-500" />
      <h2 class="text-sm font-semibold text-n-slate-12">Rendimiento por Agente</h2>
      <span class="ml-auto text-[10px] text-n-slate-9">Últimos 30 días</span>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-3">
      <div
        v-for="i in 4"
        :key="i"
        class="flex items-center gap-3 animate-pulse"
      >
        <div class="size-9 rounded-full bg-n-alpha-2 flex-shrink-0" />
        <div class="flex-1 space-y-1.5">
          <div class="h-3 bg-n-alpha-2 rounded w-1/3" />
          <div class="h-2.5 bg-n-alpha-2 rounded w-1/2" />
        </div>
        <div class="h-5 w-12 bg-n-alpha-2 rounded-full" />
      </div>
    </div>

    <!-- Agent list -->
    <div v-else-if="agents.length" class="space-y-2">
      <div
        v-for="(agent, idx) in agents"
        :key="agent.id"
        class="flex items-center gap-3 p-2.5 rounded-lg hover:bg-n-alpha-1 transition-colors"
      >
        <!-- Rank -->
        <span class="text-[10px] font-bold text-n-slate-9 w-4 text-center flex-shrink-0">
          {{ idx + 1 }}
        </span>

        <!-- Avatar -->
        <div
          class="size-9 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0"
          :style="avatarGradient(agent.name)"
        >
          {{ initials(agent.name) }}
        </div>

        <!-- Info -->
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-n-slate-12 truncate">{{ agent.name }}</p>
          <p class="text-xs text-n-slate-9">
            {{ agent.assigned }} asignados · {{ agent.resolved }} resueltos · {{ formatMinutes(agent.avg_response_minutes) }} resp.
          </p>
        </div>

        <!-- Conversion badge -->
        <span
          class="text-[10px] font-semibold px-2 py-0.5 rounded-full flex-shrink-0"
          :class="badgeClass(agent.conversion)"
        >
          {{ agent.conversion }}%
        </span>
      </div>
    </div>

    <p v-else class="text-sm text-n-slate-9 text-center py-6">
      Sin datos de agentes aún.
    </p>
  </div>
</template>
