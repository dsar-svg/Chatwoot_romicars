<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({ name: 'BotLogs' });

const getters = useStoreGetters();
const store = useStore();
const route = useRoute();

const loading = ref(true);
const filterSeveridad = ref('');
const filterTipo = ref('');
const filterDays = ref(7);

const logs = computed(() => getters['botLogs/getLogs'].value);
const meta = computed(() => getters['botLogs/getMeta'].value);

const severidades = [
  { value: '', label: 'Todas las severidades' },
  { value: 'error', label: 'Error' },
  { value: 'warning', label: 'Advertencia' },
  { value: 'info', label: 'Info' },
];

const periodos = [
  { value: 1, label: '24 h' },
  { value: 7, label: '7 días' },
  { value: 30, label: '30 días' },
  { value: 90, label: '90 días' },
];

const tipos = [
  { value: '', label: 'Todos los tipos' },
  { value: 'turno_ok', label: 'Turno OK' },
  { value: 'agente_fallo', label: 'Agente falló' },
  { value: 'redis_fallo', label: 'Redis falló' },
  { value: 'vehiculo_invalido', label: 'Vehículo inválido' },
  { value: 'cierre_sin_confirmar', label: 'Cierre sin confirmar' },
  { value: 'intencion_compra_sin_traspaso', label: 'Compra sin traspaso' },
];

const tipoLabel = tipo =>
  tipos.find(t => t.value === tipo)?.label || tipo?.replace(/_/g, ' ');

const SEVERITY_BADGE = {
  error: {
    label: 'Error',
    icon: 'i-lucide-circle-alert',
    class: 'bg-n-ruby-3 text-n-ruby-11',
  },
  warning: {
    label: 'Advertencia',
    icon: 'i-lucide-triangle-alert',
    class: 'bg-n-amber-3 text-n-amber-11',
  },
  info: {
    label: 'Info',
    icon: 'i-lucide-check',
    class: 'bg-n-teal-3 text-n-teal-11',
  },
};

const summaryCards = computed(() => [
  { key: 'total', label: 'Total de eventos', value: meta.value.total || 0 },
  {
    key: 'error',
    label: 'Errores',
    dot: 'bg-n-ruby-9',
    value: meta.value.by_severidad?.error || 0,
    alert: 'text-n-ruby-11',
  },
  {
    key: 'warning',
    label: 'Advertencias',
    dot: 'bg-n-amber-9',
    value: meta.value.by_severidad?.warning || 0,
    alert: 'text-n-amber-11',
  },
  {
    key: 'info',
    label: 'Informativos',
    dot: 'bg-n-teal-9',
    value: meta.value.by_severidad?.info || 0,
  },
]);

const hasFilters = computed(() => filterSeveridad.value || filterTipo.value);

const fetchData = async () => {
  loading.value = true;
  try {
    await store.dispatch('botLogs/fetchLogs', {
      tipoEvento: filterTipo.value || undefined,
      severidad: filterSeveridad.value || undefined,
      days: filterDays.value,
    });
  } catch (error) {
    useAlert('No se pudieron cargar los logs del bot');
  } finally {
    loading.value = false;
  }
};

const selectPeriod = days => {
  filterDays.value = days;
  fetchData();
};

onMounted(() => fetchData());

const detailOf = log => {
  if (log.detalle) return log.detalle;
  return log.tipo_evento === 'turno_ok' ? 'Sin incidencias' : '—';
};

const conversationLink = log =>
  frontendURL(
    conversationUrl({
      accountId: route.params.accountId,
      id: log.conversation_display_id || log.conversation_id,
    })
  );

const formatTime = ts => {
  if (!ts) return '—';
  const date = new Date(ts);
  const day = date.toLocaleDateString('es-VE', {
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
  });
  const time = date.toLocaleTimeString('es-VE', {
    hour: '2-digit',
    minute: '2-digit',
  });
  return `${day} · ${time}`;
};
</script>

<template>
  <SettingsLayout
    :is-loading="loading && !logs.length"
    loading-message="Cargando logs del bot..."
  >
    <template #header>
      <BaseSettingsHeader
        title="Logs del Bot"
        description="Qué hizo el bot en cada turno y dónde falló"
      >
        <template #actions>
          <Button
            label="Actualizar"
            size="sm"
            slate
            faded
            icon="i-lucide-refresh-cw"
            :is-loading="loading"
            @click="fetchData"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <div
          v-for="card in summaryCards"
          :key="card.key"
          class="flex flex-col gap-2 p-4 rounded-xl border border-n-weak bg-n-solid-2"
        >
          <div class="flex items-center gap-1.5">
            <span
              v-if="card.dot"
              class="size-2 rounded-full"
              :class="card.dot"
            />
            <span class="text-xs text-n-slate-11">{{ card.label }}</span>
          </div>
          <span
            class="text-[28px] font-bold leading-none tabular-nums"
            :class="
              card.alert && card.value > 0 ? card.alert : 'text-n-slate-12'
            "
          >
            {{ card.value }}
          </span>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-3 mb-4">
        <ComboBox
          v-model="filterSeveridad"
          class="!w-52"
          :options="severidades"
          placeholder="Todas las severidades"
          @update:model-value="fetchData"
        />
        <ComboBox
          v-model="filterTipo"
          class="!w-52"
          :options="tipos"
          placeholder="Todos los tipos"
          search-placeholder="Buscar tipo..."
          @update:model-value="fetchData"
        />
        <div
          role="group"
          aria-label="Período"
          class="flex items-center gap-0.5 p-0.5 rounded-lg border border-n-weak bg-n-solid-2"
        >
          <button
            v-for="periodo in periodos"
            :key="periodo.value"
            type="button"
            class="px-3 py-1.5 rounded-md text-sm transition-colors"
            :class="
              filterDays === periodo.value
                ? 'bg-n-brand text-white font-semibold'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            :aria-pressed="filterDays === periodo.value"
            @click="selectPeriod(periodo.value)"
          >
            {{ periodo.label }}
          </button>
        </div>
      </div>

      <BaseTable
        :headers="['Fecha', 'Tipo', 'Severidad', 'Detalle', 'Conversación']"
        :items="logs"
        :loading="loading"
        :no-data-message="
          hasFilters
            ? 'No hay logs con esos filtros en este período'
            : 'No hay logs del bot en este período'
        "
      >
        <template #header-4>
          <span class="block text-end">Conversación</span>
        </template>
        <template #row="{ items }">
          <BaseTableRow
            v-for="log in items"
            :key="log.id"
            :item="log"
            :class="{ 'bg-n-ruby-2': log.severidad === 'error' }"
          >
            <template #default>
              <BaseTableCell class="w-44">
                <span
                  class="text-xs text-n-slate-11 whitespace-nowrap tabular-nums"
                >
                  {{ formatTime(log.created_at) }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-48">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ tipoLabel(log.tipo_evento) }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-32">
                <span
                  v-if="SEVERITY_BADGE[log.severidad]"
                  class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-semibold"
                  :class="SEVERITY_BADGE[log.severidad].class"
                >
                  <span
                    class="size-3"
                    :class="SEVERITY_BADGE[log.severidad].icon"
                  />
                  {{ SEVERITY_BADGE[log.severidad].label }}
                </span>
                <span v-else class="text-xs text-n-slate-11">
                  {{ log.severidad }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="max-w-md">
                <span
                  class="text-sm whitespace-normal"
                  :class="log.detalle ? 'text-n-slate-12' : 'text-n-slate-10'"
                >
                  {{ detailOf(log) }}
                </span>
              </BaseTableCell>
              <BaseTableCell align="end" class="w-32">
                <router-link
                  v-if="log.conversation_display_id || log.conversation_id"
                  :to="conversationLink(log)"
                  class="inline-flex items-center gap-1 text-sm font-medium text-n-blue-11 hover:underline"
                >
                  #{{ log.conversation_display_id || log.conversation_id }}
                  <span class="i-lucide-external-link size-3.5" />
                </router-link>
                <span v-else class="text-sm text-n-slate-10">—</span>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
  </SettingsLayout>
</template>
