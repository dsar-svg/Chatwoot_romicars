<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({ name: 'BotLogs' });

const getters = useStoreGetters();
const store = useStore();

const loading = ref(true);
const filterSeveridad = ref('');
const filterTipo = ref('');
const filterDays = ref(7);

const logs = computed(() => getters['botLogs/getLogs'].value);
const meta = computed(() => getters['botLogs/getMeta'].value);

const severidades = [
  { value: '', label: 'Todas' },
  { value: 'error', label: 'Error' },
  { value: 'warning', label: 'Warning' },
  { value: 'info', label: 'Info' },
];

const tipos = [
  { value: '', label: 'Todos' },
  { value: 'turno_ok', label: 'Turno OK' },
  { value: 'agente_fallo', label: 'Agente falló' },
  { value: 'redis_fallo', label: 'Redis falló' },
  { value: 'vehiculo_invalido', label: 'Vehículo inválido' },
  { value: 'cierre_sin_confirmar', label: 'Cierre sin confirmar' },
  { value: 'intencion_compra_sin_traspaso', label: 'Compra sin traspaso' },
];

const fetchData = async () => {
  loading.value = true;
  try {
    await store.dispatch('botLogs/fetchLogs', {
      tipoEvento: filterTipo.value || undefined,
      severidad: filterSeveridad.value || undefined,
      days: filterDays.value,
    });
  } catch (error) {
    // Ignore
  } finally {
    loading.value = false;
  }
};

onMounted(() => fetchData());

const severityColor = sev => {
  if (sev === 'error') return 'text-n-ruby-11';
  if (sev === 'warning') return 'text-n-amber-11';
  return 'text-n-slate-11';
};

const formatTime = ts => {
  if (!ts) return '—';
  return new Date(ts).toLocaleString('es-VE', {
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
};
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    :loading-message="'Cargando logs del bot...'"
    :no-records-found="!loading && !logs.length"
    :no-records-message="'No hay logs del bot en este período'"
  >
    <template #header>
      <BaseSettingsHeader title="Logs del Bot">
        <template #actions>
          <Button
            label="Actualizar"
            size="sm"
            slate
            ghost
            icon="i-lucide-refresh-cw"
            @click="fetchData"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <!-- KPI Cards -->
      <div class="grid grid-cols-4 gap-3 mb-6">
        <div class="p-3 rounded-lg bg-n-alpha-2">
          <div class="text-xs text-n-slate-11 mb-1">Total</div>
          <div class="text-xl font-bold text-n-slate-12">{{ meta.total || 0 }}</div>
        </div>
        <div class="p-3 rounded-lg bg-n-ruby-2">
          <div class="text-xs text-n-ruby-11 mb-1">Errors</div>
          <div class="text-xl font-bold text-n-ruby-12">
            {{ meta.by_severidad?.error || 0 }}
          </div>
        </div>
        <div class="p-3 rounded-lg bg-n-amber-2">
          <div class="text-xs text-n-amber-11 mb-1">Warnings</div>
          <div class="text-xl font-bold text-n-amber-12">
            {{ meta.by_severidad?.warning || 0 }}
          </div>
        </div>
        <div class="p-3 rounded-lg bg-n-green-2">
          <div class="text-xs text-n-green-11 mb-1">Info</div>
          <div class="text-xl font-bold text-n-green-12">
            {{ meta.by_severidad?.info || 0 }}
          </div>
        </div>
      </div>

      <!-- Filtros -->
      <div class="flex items-center gap-3 mb-4">
        <select v-model="filterSeveridad" class="text-sm px-3 py-1.5 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12">
          <option v-for="s in severidades" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
        <select v-model="filterTipo" class="text-sm px-3 py-1.5 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12">
          <option v-for="t in tipos" :key="t.value" :value="t.value">{{ t.label }}</option>
        </select>
        <select v-model="filterDays" class="text-sm px-3 py-1.5 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12">
          <option :value="1">Último día</option>
          <option :value="7">Últimos 7 días</option>
          <option :value="30">Últimos 30 días</option>
          <option :value="90">Últimos 90 días</option>
        </select>
        <Button label="Buscar" size="sm" slate @click="fetchData" />
      </div>

      <!-- Tabla -->
      <BaseTable
        :headers="['Fecha', 'Tipo', 'Severidad', 'Detalle', 'Conversación']"
        :items="logs"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="log in items" :key="log.id" :item="log">
            <template #default>
              <BaseTableCell class="w-36">
                <span class="text-xs text-n-slate-11 whitespace-nowrap">
                  {{ formatTime(log.created_at) }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-44">
                <span class="text-xs font-medium text-n-slate-12">
                  {{ log.tipo_evento?.replace(/_/g, ' ') }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-20">
                <span class="text-xs font-medium" :class="severityColor(log.severidad)">
                  {{ log.severidad }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="max-w-xs">
                <span class="text-xs text-n-slate-11 whitespace-normal">
                  {{ log.detalle || '—' }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-28">
                <span class="text-xs text-n-slate-11">
                  #{{ log.conversation_display_id || log.conversation_id }}
                </span>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
  </SettingsLayout>
</template>
