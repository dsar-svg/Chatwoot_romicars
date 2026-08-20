<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import api from 'dashboard/api/romicarsAnalytics';
import AIInsights from './components/AIInsights.vue';
import KPICards from './components/KPICards.vue';
import LeadMetrics from './components/LeadMetrics.vue';
import AgentPerformance from './components/AgentPerformance.vue';
import ProductDemand from './components/ProductDemand.vue';
import ProfitProducts from './components/ProfitProducts.vue';
import VenezuelaMap from './components/VenezuelaMap.vue';
import ResolutionBreakdown from './components/ResolutionBreakdown.vue';
import MetricDetailModal from './components/MetricDetailModal.vue';

const loading = ref({
  overview: true,
  agents: true,
  demand: true,
  aiInsights: true,
  profit: true,
});

const overview = ref({ kpis: {}, mini_metrics: {} });
const agents = ref([]);
const demand = ref({});
const aiInsights = ref({ insights: [], source: 'rules' });
const profit = ref({ products_top: [], products_bottom: [], customers: [], available: false });

const lastUpdated = ref(null);

// Modal state
const showModal = ref(false);
const modalType = ref('');
const modalLabel = ref('');
const modalItems = ref([]);
const modalTotal = ref(0);
const modalLoading = ref(false);

async function loadOverview() {
  try {
    const { data } = await api.getOverview();
    overview.value = data;
  } finally {
    loading.value.overview = false;
  }
}

async function loadAgents() {
  try {
    const { data } = await api.getAgents();
    agents.value = data;
  } finally {
    loading.value.agents = false;
  }
}

async function loadDemand() {
  try {
    const { data } = await api.getDemand();
    demand.value = data;
  } finally {
    loading.value.demand = false;
  }
}

async function loadAIInsights() {
  try {
    const { data } = await api.getAIInsights();
    aiInsights.value = data;
  } finally {
    loading.value.aiInsights = false;
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
  Object.keys(loading.value).forEach(k => { loading.value[k] = true; });
  await Promise.allSettled([loadOverview(), loadAgents(), loadDemand(), loadAIInsights(), loadProfit()]);
  lastUpdated.value = new Date().toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' });
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
    const { data } = await api.getMiniMetricsDetail(type);
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
        <h1 class="text-2xl font-bold text-n-slate-12 tracking-tight">Dashboard</h1>
        <p class="text-sm text-n-slate-10 mt-0.5">Inteligencia de negocio · Autopartes</p>
      </div>
      <div class="flex items-center gap-3">
        <div v-if="lastUpdated" class="text-xs text-n-slate-9">
          Actualizado {{ lastUpdated }}
        </div>
      </div>
    </div>

    <!-- AI Insights -->
    <AIInsights
      :insights="aiInsights.insights"
      :source="aiInsights.source"
      :loading="loading.aiInsights"
    />

    <!-- KPI Cards -->
    <KPICards
      :kpis="overview.kpis"
      :loading="loading.overview"
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
      />
      <ProductDemand
        :demand="demand"
        :loading="loading.demand"
      />
    </div>

    <!-- Resolution Breakdown -->
    <ResolutionBreakdown />

    <!-- Profit Products + Venezuela Map -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <ProfitProducts
        :products-top="profit.products_top"
        :products-bottom="profit.products_bottom"
        :available="profit.available"
        :loading="loading.profit"
      />
      <VenezuelaMap
        :customers="profit.customers"
        :loading="loading.profit"
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
</template>
