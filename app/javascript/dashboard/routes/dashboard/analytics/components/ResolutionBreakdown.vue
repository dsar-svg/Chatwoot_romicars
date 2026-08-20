<script setup>
import { ref, computed, onMounted } from 'vue';
import api from 'dashboard/api/romicarsAnalytics';

const loading = ref(true);
const data = ref(null);

async function loadData() {
  loading.value = true;
  try {
    const response = await api.getResolution();
    data.value = response.data;
  } catch (e) {
    // ignore
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);

const totalResolved = computed(() => data.value?.total_resolved || 0);
const ganadoCount = computed(() => data.value?.ganado?.count || 0);
const perdidoCount = computed(() => data.value?.perdido?.count || 0);
const consultaCount = computed(() => data.value?.consulta?.count || 0);

const perdidoReasons = computed(() => {
  const byReason = data.value?.perdido?.by_reason || {};
  return [
    { key: 'sin_stock', label: 'Sin stock', count: byReason.sin_stock || 0, color: 'amber' },
    { key: 'precio', label: 'Precio', count: byReason.precio || 0, color: 'iris' },
    { key: 'sin_respuesta', label: 'Sin respuesta', count: byReason.sin_respuesta || 0, color: 'slate' },
    { key: 'otro', label: 'Otro', count: byReason.otro || 0, color: 'slate' },
  ].filter(r => r.count > 0);
});

const barMax = computed(() => {
  const counts = [ganadoCount.value, perdidoCount.value, consultaCount.value];
  return Math.max(...counts, 1);
});

function barWidth(count) {
  return `${(count / barMax.value) * 100}%`;
}
</script>

<template>
  <div class="rounded-xl border border-n-strong bg-n-solid-1 p-5">
    <div class="flex items-center justify-between mb-4">
      <div>
        <h3 class="text-sm font-semibold text-n-slate-12">Resolución de Conversaciones</h3>
        <p class="text-xs text-n-slate-10 mt-0.5">Últimos 30 días · {{ totalResolved }} total</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-8">
      <span class="text-xs text-n-slate-10">Cargando...</span>
    </div>

    <div v-else-if="totalResolved === 0" class="flex items-center justify-center py-8">
      <span class="text-xs text-n-slate-10">Sin resoluciones registradas</span>
    </div>

    <div v-else class="space-y-4">
      <!-- Bar chart -->
      <div class="space-y-2">
        <!-- Ganado -->
        <div class="flex items-center gap-3">
          <span class="text-xs text-n-slate-11 w-20 text-right">Ventas</span>
          <div class="flex-1 h-6 bg-n-alpha-2 rounded overflow-hidden">
            <div
              class="h-full bg-n-green-9 rounded transition-all duration-500"
              :style="{ width: barWidth(ganadoCount) }"
            />
          </div>
          <span class="text-xs font-medium text-n-green-11 w-12 text-right">
            {{ ganadoCount }}
          </span>
        </div>

        <!-- Perdido -->
        <div class="flex items-center gap-3">
          <span class="text-xs text-n-slate-11 w-20 text-right">Perdidas</span>
          <div class="flex-1 h-6 bg-n-alpha-2 rounded overflow-hidden">
            <div
              class="h-full bg-n-ruby-9 rounded transition-all duration-500"
              :style="{ width: barWidth(perdidoCount) }"
            />
          </div>
          <span class="text-xs font-medium text-n-ruby-11 w-12 text-right">
            {{ perdidoCount }}
          </span>
        </div>

        <!-- Consulta -->
        <div v-if="consultaCount > 0" class="flex items-center gap-3">
          <span class="text-xs text-n-slate-11 w-20 text-right">Consultas</span>
          <div class="flex-1 h-6 bg-n-alpha-2 rounded overflow-hidden">
            <div
              class="h-full bg-n-blue-9 rounded transition-all duration-500"
              :style="{ width: barWidth(consultaCount) }"
            />
          </div>
          <span class="text-xs font-medium text-n-blue-11 w-12 text-right">
            {{ consultaCount }}
          </span>
        </div>
      </div>

      <!-- Motivos de pérdida -->
      <div v-if="perdidoReasons.length > 0">
        <h4 class="text-xs font-medium text-n-slate-11 mb-2">Motivos de pérdida</h4>
        <div class="grid grid-cols-2 gap-2">
          <div
            v-for="reason in perdidoReasons"
            :key="reason.key"
            class="flex items-center justify-between px-3 py-2 rounded-lg bg-n-alpha-2"
          >
            <span class="text-xs text-n-slate-11">{{ reason.label }}</span>
            <span class="text-xs font-medium text-n-slate-12">{{ reason.count }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
