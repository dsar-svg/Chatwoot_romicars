<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({
  name: 'ResolutionReports',
});

const getters = useStoreGetters();
const store = useStore();

const loading = ref(true);
const resolutionData = ref(null);
const requestedProductsData = ref(null);

const fetchData = async () => {
  loading.value = true;
  try {
    const [resolutionResponse, requestedResponse] = await Promise.all([
      store.dispatch('romicarsAnalytics/fetchResolution'),
      store.dispatch('romicarsAnalytics/fetchRequestedProducts'),
    ]);
    resolutionData.value = resolutionResponse;
    requestedProductsData.value = requestedResponse;
  } catch (error) {
    // Ignore
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchData();
});

const ganadoCount = computed(() => resolutionData.value?.ganado?.count || 0);
const ganadoPct = computed(() => resolutionData.value?.ganado?.percentage || 0);
const perdidoCount = computed(() => resolutionData.value?.perdido?.count || 0);
const perdidoPct = computed(() => resolutionData.value?.perdido?.percentage || 0);
const totalResolved = computed(() => resolutionData.value?.total_resolved || 0);
const totalSalesAmount = computed(
  () => resolutionData.value?.ganado?.total_sales_amount || 0
);
const averageSale = computed(() => resolutionData.value?.ganado?.average_sale || 0);
const recentSales = computed(() => resolutionData.value?.ganado?.sales || []);

const formatCurrency = value => {
  if (!value) return '—';
  return `$${Number(value).toFixed(2)}`;
};

const perdidoReasons = computed(() => {
  const byReason = resolutionData.value?.perdido?.by_reason || {};
  return [
    { reason: 'Sin stock', count: byReason.sin_stock || 0 },
    { reason: 'Precio', count: byReason.precio || 0 },
    { reason: 'Sin respuesta', count: byReason.sin_respuesta || 0 },
    { reason: 'Otro', count: byReason.otro || 0 },
  ].filter(r => r.count > 0);
});

const agentStats = computed(() => {
  const data = resolutionData.value?.by_agent || [];
  const grouped = {};
  data.forEach(item => {
    if (!grouped[item.agent]) {
      grouped[item.agent] = { agent: item.agent, ganado: 0, perdido: 0 };
    }
    grouped[item.agent][item.type] = item.count;
  });
  return Object.values(grouped).sort((a, b) => b.ganado - a.ganado);
});

const dailyStats = computed(() => {
  const data = resolutionData.value?.daily || [];
  const grouped = {};
  data.forEach(item => {
    if (!grouped[item.date]) {
      grouped[item.date] = { date: item.date, ganado: 0, perdido: 0 };
    }
    grouped[item.date][item.type] = item.count;
  });
  return Object.values(grouped).sort((a, b) => b.date.localeCompare(a.date));
});

const formatPct = value => `${value}%`;

const totalRequestedProducts = computed(
  () => requestedProductsData.value?.total_requested || 0
);
const uniqueProducts = computed(
  () => requestedProductsData.value?.unique_products || 0
);
const requestedProductsList = computed(
  () => requestedProductsData.value?.products || {}
);
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    :loading-message="'Cargando reportes de resolución...'"
    :no-records-found="!loading && !resolutionData"
    :no-records-message="'No hay datos de resolución disponibles'"
  >
    <template #header>
      <BaseSettingsHeader title="Reportes de Resolución">
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
      <div class="grid grid-cols-3 gap-4 mb-6">
        <div class="p-4 rounded-lg bg-n-alpha-2">
          <div class="text-sm text-n-slate-11 mb-1">Total Resueltas</div>
          <div class="text-2xl font-bold text-n-slate-12">
            {{ totalResolved }}
          </div>
        </div>
        <div class="p-4 rounded-lg bg-n-green-2">
          <div class="text-sm text-n-green-11 mb-1">Ganadas (Ventas)</div>
          <div class="text-2xl font-bold text-n-green-12">
            {{ ganadoCount }}
            <span class="text-sm font-normal text-n-green-11">
              ({{ formatPct(ganadoPct) }})
            </span>
          </div>
        </div>
        <div class="p-4 rounded-lg bg-n-ruby-2">
          <div class="text-sm text-n-ruby-11 mb-1">Perdidas</div>
          <div class="text-2xl font-bold text-n-ruby-12">
            {{ perdidoCount }}
            <span class="text-sm font-normal text-n-ruby-11">
              ({{ formatPct(perdidoPct) }})
            </span>
          </div>
        </div>
        <div class="p-4 rounded-lg bg-n-blue-2">
          <div class="text-sm text-n-blue-11 mb-1">Monto total ventas</div>
          <div class="text-2xl font-bold text-n-blue-12">
            {{ formatCurrency(totalSalesAmount) }}
          </div>
        </div>
        <div class="p-4 rounded-lg bg-n-alpha-2">
          <div class="text-sm text-n-slate-11 mb-1">Promedio por venta</div>
          <div class="text-2xl font-bold text-n-slate-12">
            {{ formatCurrency(averageSale) }}
          </div>
        </div>
      </div>

      <!-- Ventas recientes -->
      <div v-if="recentSales.length" class="mb-6">
        <h3 class="text-heading-3 text-n-slate-12 mb-3">
          Ventas recientes
        </h3>
        <BaseTable
          :headers="['Conversación', 'Contacto', 'Fecha', 'Monto', 'Factura']"
          :items="recentSales"
        >
          <template #row="{ items }">
            <BaseTableRow v-for="sale in items" :key="sale.id" :item="sale">
              <template #default>
                <BaseTableCell class="w-24">
                  <span class="text-sm text-n-slate-12">#{{ sale.id }}</span>
                </BaseTableCell>
                <BaseTableCell class="max-w-0">
                  <span class="text-sm text-n-slate-12">
                    {{ sale.contact || '—' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-28">
                  <span class="text-sm text-n-slate-11">{{ sale.date }}</span>
                </BaseTableCell>
                <BaseTableCell class="w-28">
                  <span class="text-sm font-medium text-n-green-11">
                    {{ formatCurrency(sale.amount) }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-28">
                  <span class="text-sm text-n-slate-11">
                    {{ sale.invoice || '—' }}
                  </span>
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>

      <!-- Perdidos por motivo -->
      <div v-if="perdidoReasons.length" class="mb-6">
        <h3 class="text-heading-3 text-n-slate-12 mb-3">
          Motivos de pérdida
        </h3>
        <div class="grid grid-cols-4 gap-3">
          <div
            v-for="item in perdidoReasons"
            :key="item.reason"
            class="p-3 rounded-lg bg-n-alpha-2"
          >
            <div class="text-sm text-n-slate-11">{{ item.reason }}</div>
            <div class="text-lg font-bold text-n-slate-12">
              {{ item.count }}
            </div>
          </div>
        </div>
      </div>

      <!-- Productos solicitados sin stock -->
      <div v-if="totalRequestedProducts > 0" class="mb-6">
        <h3 class="text-heading-3 text-n-slate-12 mb-3">
          Productos solicitados sin stock
        </h3>
        <div class="grid grid-cols-2 gap-4 mb-3">
          <div class="p-3 rounded-lg bg-n-amber-2">
            <div class="text-sm text-n-amber-11">Total solicitudes</div>
            <div class="text-2xl font-bold text-n-amber-12">
              {{ totalRequestedProducts }}
            </div>
          </div>
          <div class="p-3 rounded-lg bg-n-alpha-2">
            <div class="text-sm text-n-slate-11">Productos únicos</div>
            <div class="text-2xl font-bold text-n-slate-12">
              {{ uniqueProducts }}
            </div>
          </div>
        </div>
        <BaseTable
          :headers="['Producto', 'Solicitudes', 'Última conversación']"
          :items="Object.entries(requestedProductsList)"
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="[product, data] in items"
              :key="product"
              :item="{ product, ...data }"
            >
              <template #default>
                <BaseTableCell class="max-w-0">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ product }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-24">
                  <span class="text-sm font-medium text-n-amber-11">
                    {{ data.count }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-40">
                  <span class="text-sm text-n-slate-11">
                    #{{ data.conversations[0]?.id }} —
                    {{ data.conversations[0]?.contact || '—' }}
                  </span>
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>

      <!-- Estadísticas por agente -->
      <div v-if="agentStats.length" class="mb-6">
        <h3 class="text-heading-3 text-n-slate-12 mb-3">
          Rendimiento por agente
        </h3>
        <BaseTable
          :headers="['Agente', 'Ganadas', 'Perdidas', 'Total']"
          :items="agentStats"
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="stat in items"
              :key="stat.agent"
              :item="stat"
            >
              <template #default>
                <BaseTableCell class="max-w-0">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ stat.agent }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-24">
                  <span class="text-sm text-n-green-11 font-medium">
                    {{ stat.ganado }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-24">
                  <span class="text-sm text-n-ruby-11 font-medium">
                    {{ stat.perdido }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-24">
                  <span class="text-sm text-n-slate-11">
                    {{ stat.ganado + stat.perdido }}
                  </span>
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>

      <!-- Últimos 30 días -->
      <div v-if="dailyStats.length">
        <h3 class="text-heading-3 text-n-slate-12 mb-3">
          Resolución diaria (últimos 30 días)
        </h3>
        <BaseTable
          :headers="['Fecha', 'Ganadas', 'Perdidas']"
          :items="dailyStats"
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="stat in items"
              :key="stat.date"
              :item="stat"
            >
              <template #default>
                <BaseTableCell class="w-32">
                  <span class="text-sm text-n-slate-12">{{ stat.date }}</span>
                </BaseTableCell>
                <BaseTableCell class="w-24">
                  <span class="text-sm text-n-green-11 font-medium">
                    {{ stat.ganado }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-24">
                  <span class="text-sm text-n-ruby-11 font-medium">
                    {{ stat.perdido }}
                  </span>
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>
    </template>
  </SettingsLayout>
</template>
