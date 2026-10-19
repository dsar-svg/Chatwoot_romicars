<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import api from 'dashboard/api/romicarsAnalytics';
import { useAlert } from 'dashboard/composables';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import AIInsights from './components/AIInsights.vue';
import KPICards from './components/KPICards.vue';
import LeadMetrics from './components/LeadMetrics.vue';
import AgentPerformance from './components/AgentPerformance.vue';
import ProductDemand from './components/ProductDemand.vue';
import ProfitProducts from './components/ProfitProducts.vue';
import VenezuelaMap from './components/VenezuelaMap.vue';
import ResolutionBreakdown from './components/ResolutionBreakdown.vue';
import WinLossAnalysis from './components/WinLossAnalysis.vue';
import MetricDetailModal from './components/MetricDetailModal.vue';
import LocationsModal from './components/LocationsModal.vue';
import DashboardFilters from './components/DashboardFilters.vue';
import { periodRange } from './period';

const loading = ref({
  overview: true,
  agents: true,
  demand: true,
  aiInsights: true,
  winLoss: true,
  profit: true,
  locations: true,
});

const overview = ref({ kpis: {}, mini_metrics: {} });
const agents = ref([]);
const demand = ref({});
const aiInsights = ref({ insights: [], source: 'rules' });
const winLoss = ref({
  perdidas: { total: 0, causas: [], patrones: [], repuestos_sin_stock: [] },
  ganadas: { total: 0, practicas: [], patrones: [] },
  conversaciones_analizadas: 0,
  conversaciones_nuevas: 0,
  source: 'rules',
});
const profit = ref({
  products_top: [],
  products_bottom: [],
  customers: [],
  available: false,
});

const contactLocations = ref({ locations: [], without_city: 0 });
const showLocations = ref(false);

const lastUpdated = ref(null);

// The two AI panels take seconds to come back and used to sit at the top, so the whole
// dashboard looked like it was still loading while the numbers below were already there.
const TABS = [{ label: 'Operación' }, { label: 'Insights IA' }];
const activeTab = ref(0);

function handleTabChange(tab) {
  activeTab.value = TABS.findIndex(({ label }) => label === tab.label);
}

// Filters of the Operación tab. Insights IA ignores them on purpose (see the controller).
const filters = ref({
  preset: '30d',
  from: '',
  to: '',
  channel: '',
  agentId: '',
});
const inboxes = useMapGetter('inboxes/getInboxes');

const range = computed(() => {
  const { preset, from, to } = filters.value;
  return periodRange(preset, { from, to });
});
const periodLabel = computed(() => range.value?.label || '');

const filterParams = computed(() => {
  const { channel, agentId } = filters.value;
  const params = {};
  const { since, until } = range.value || {};
  if (since) params.since = since.toISOString();
  if (until) params.until = until.toISOString();
  if (channel) {
    params.inbox_ids = inboxes.value
      .filter(inbox => inbox.channel_type === channel)
      .map(inbox => inbox.id);
  }
  if (agentId) params.agent_id = agentId;
  return params;
});

// Modal state
const showModal = ref(false);
const modalType = ref('');
const modalLabel = ref('');
const modalItems = ref([]);
const modalTotal = ref(0);
const modalLoading = ref(false);

async function loadOverview() {
  try {
    const { data } = await api.getOverview(filterParams.value);
    overview.value = data;
  } finally {
    loading.value.overview = false;
  }
}

async function loadAgents() {
  try {
    const { data } = await api.getAgents(filterParams.value);
    agents.value = data;
  } finally {
    loading.value.agents = false;
  }
}

async function loadDemand() {
  try {
    const { data } = await api.getDemand(filterParams.value);
    demand.value = data;
  } finally {
    loading.value.demand = false;
  }
}

async function loadAIInsights(options) {
  try {
    const { data } = await api.getAIInsights(options);
    aiInsights.value = data;
  } finally {
    loading.value.aiInsights = false;
  }
}

async function loadWinLoss(options) {
  try {
    const { data } = await api.getWinLoss(options);
    winLoss.value = data;
  } finally {
    loading.value.winLoss = false;
  }
}

// The server keeps both answers for hours. This asks the model again on demand.
async function regenerateInsights() {
  loading.value.aiInsights = true;
  loading.value.winLoss = true;
  const results = await Promise.allSettled([
    loadAIInsights({ refresh: true }),
    loadWinLoss({ refresh: true }),
  ]);
  if (results.some(({ status }) => status === 'rejected')) {
    useAlert('No se pudo actualizar el análisis');
  }
}

async function loadContactLocations() {
  try {
    const { data } = await api.getContactLocations(filterParams.value);
    contactLocations.value = data;
  } finally {
    loading.value.locations = false;
  }
}

async function loadProfit() {
  try {
    const { data } = await api.getProfit();
    profit.value = data;
  } finally {
    loading.value.profit = false;
  }
}

async function refresh() {
  Object.keys(loading.value).forEach(k => {
    loading.value[k] = true;
  });
  const results = await Promise.allSettled([
    loadOverview(),
    loadAgents(),
    loadDemand(),
    loadAIInsights(),
    loadWinLoss(),
    loadProfit(),
    loadContactLocations(),
  ]);
  if (results.some(r => r.status === 'rejected')) {
    useAlert('Algunas secciones del dashboard no se pudieron cargar');
  }
  lastUpdated.value = new Date().toLocaleTimeString('es-VE', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

const cardLabels = {
  new_today: 'Nuevos Hoy',
  pending: 'Pendientes',
  high_urgency: 'Alta Urgencia',
  bot: 'En Bot',
  agent: 'En Agente',
  resolved_today: 'Resueltos Hoy',
};

async function handleCardClick(type) {
  modalType.value = type;
  modalLabel.value = cardLabels[type] || type;
  modalItems.value = [];
  modalTotal.value = 0;
  showModal.value = true;
  modalLoading.value = true;

  try {
    const { data } = await api.getMiniMetricsDetail(type, filterParams.value);
    modalItems.value = data.items || [];
    modalTotal.value = data.total || 0;
  } catch (e) {
    modalItems.value = [];
    modalTotal.value = 0;
  } finally {
    modalLoading.value = false;
  }
}

function handleCloseModal() {
  showModal.value = false;
}

// Only the Operación sections: a filter change must not ask OpenAI again.
async function refreshOperation() {
  ['overview', 'agents', 'demand', 'locations'].forEach(key => {
    loading.value[key] = true;
  });
  const results = await Promise.allSettled([
    loadOverview(),
    loadAgents(),
    loadDemand(),
    loadContactLocations(),
  ]);
  if (results.some(r => r.status === 'rejected')) {
    useAlert('Algunas secciones del dashboard no se pudieron cargar');
  }
}

// A custom range still being typed has no range yet: keep what is on screen.
watch(filterParams, () => {
  if (filters.value.preset !== 'custom' || range.value) refreshOperation();
});

let refreshInterval = null;

onMounted(() => {
  refresh();
  refreshInterval = setInterval(refresh, 300000);
});

onUnmounted(() => {
  if (refreshInterval) clearInterval(refreshInterval);
});
</script>

<template>
  <div class="flex-1 overflow-y-auto h-full">
    <div class="flex flex-col gap-6 p-6 max-w-7xl mx-auto w-full pb-10">
      <!-- Header -->
      <div class="flex items-start justify-between">
        <div>
          <h1 class="text-2xl font-bold text-n-slate-12 tracking-tight">
            Dashboard
          </h1>
          <p class="text-sm text-n-slate-10 mt-0.5">
            Inteligencia de negocio · Autopartes
          </p>
        </div>
        <div class="flex items-center gap-3">
          <div v-if="lastUpdated" class="text-xs text-n-slate-9">
            Actualizado {{ lastUpdated }}
          </div>
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3">
        <TabBar
          :tabs="TABS"
          :initial-active-tab="activeTab"
          @tab-changed="handleTabChange"
        />
        <DashboardFilters v-show="activeTab === 0" v-model="filters" />
      </div>

      <!-- v-show, not v-if: ResolutionBreakdown loads its own data on mount and would
           refetch on every tab switch. -->
      <div v-show="activeTab === 0" class="flex flex-col gap-6">
        <!-- KPI Cards -->
        <KPICards
          :kpis="overview.kpis"
          :loading="loading.overview"
          :period-label="periodLabel"
        />

        <!-- Mini metrics -->
        <LeadMetrics
          :metrics="overview.mini_metrics"
          :loading="loading.overview"
          @card-click="handleCardClick"
        />

        <!-- Agent + Demand -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <AgentPerformance
            :agents="agents"
            :loading="loading.agents"
            :period-label="periodLabel"
          />
          <ProductDemand
            :demand="demand"
            :loading="loading.demand"
            :period-label="periodLabel"
          />
        </div>

        <!-- Resolution Breakdown -->
        <ResolutionBreakdown
          :params="filterParams"
          :period-label="periodLabel"
        />

        <!-- Profit Products + Venezuela Map -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <ProfitProducts
            :products-top="profit.products_top"
            :products-bottom="profit.products_bottom"
            :available="profit.available"
            :loading="loading.profit"
          />
          <VenezuelaMap
            :locations="contactLocations.locations"
            :without-city="contactLocations.without_city"
            :loading="loading.locations"
            @open="showLocations = true"
          />
        </div>
      </div>

      <div v-show="activeTab === 1" class="flex flex-col gap-6">
        <div class="flex justify-end">
          <Button
            slate
            faded
            sm
            icon="i-lucide-refresh-cw"
            label="Actualizar análisis"
            :is-loading="loading.aiInsights || loading.winLoss"
            @click="regenerateInsights"
          />
        </div>
        <!-- AI Insights -->
        <AIInsights
          :insights="aiInsights.insights"
          :source="aiInsights.source"
          :loading="loading.aiInsights"
        />

        <!-- Win / loss analysis -->
        <WinLossAnalysis
          :perdidas="winLoss.perdidas"
          :ganadas="winLoss.ganadas"
          :analizadas="winLoss.conversaciones_analizadas"
          :nuevas="winLoss.conversaciones_nuevas"
          :source="winLoss.source"
          :loading="loading.winLoss"
        />
      </div>
    </div>
  </div>

  <!-- Metric Detail Modal -->
  <MetricDetailModal
    :show="showModal"
    :type="modalType"
    :label="modalLabel"
    :items="modalItems"
    :total="modalTotal"
    :loading="modalLoading"
    @close="handleCloseModal"
  />

  <LocationsModal
    :show="showLocations"
    :locations="contactLocations.locations"
    :params="filterParams"
    @close="showLocations = false"
  />
</template>
