<script setup>
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref, watch } from 'vue';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';
import AddPrice from './AddPrice.vue';
import EditPrice from './EditPrice.vue';
import ImportPrices from './ImportPrices.vue';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({
  name: 'VehiclePriceSettings',
});

const getters = useStoreGetters();
const store = useStore();

const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showImportPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activePrice = ref({});
const loading = ref({});
const searchQuery = ref('');
const debouncedQuery = ref('');
const filterBrand = ref('');
const filterModel = ref('');
const page = ref(1);
const perPage = 50;
let debounceTimer = null;

const records = computed(() => getters['vehiclePrices/getPrices'].value);
const uiFlags = computed(() => getters['vehiclePrices/getUIFlags'].value);
const rateFlags = computed(() => getters['exchangeRates/getUIFlags'].value);
const brands = computed(() => getters['vehicleBrands/getBrands'].value);
const models = computed(() => getters['vehicleModels/getModels'].value);
const latestRate = computed(() => getters['exchangeRates/getLatestRate'].value);

const filteredModels = computed(() => {
  if (!filterBrand.value) return [];
  return models.value.filter(
    m => m.brand?.id === Number(filterBrand.value)
  );
});

const filteredRecords = computed(() => {
  let items = records.value;

  if (filterBrand.value) {
    items = items.filter(p => p.brand?.id === Number(filterBrand.value));
  }
  if (filterModel.value) {
    items = items.filter(p => p.model?.id === Number(filterModel.value));
  }

  const query = debouncedQuery.value.trim();
  if (query) {
    items = picoSearch(items, query, ['description', 'variant']);
  }

  return items;
});

const totalPages = computed(() =>
  Math.ceil(filteredRecords.value.length / perPage)
);

const pagedRecords = computed(() => {
  const start = (page.value - 1) * perPage;
  return filteredRecords.value.slice(start, start + perPage);
});

const calcCostBs = divisor => {
  if (!divisor || !latestRate.value) return null;
  return Number((divisor * latestRate.value.equiv_13).toFixed(2));
};

const calcBolivares = divisor => {
  if (!divisor) return null;
  return Number((divisor * 1.13).toFixed(2));
};

const fetchPrices = async () => {
  try {
    await store.dispatch('vehiclePrices/get');
  } catch (error) {
    // Ignore Error
  }
};

const fetchBrands = async () => {
  try {
    await store.dispatch('vehicleBrands/get');
  } catch (error) {
    // Ignore Error
  }
};

const fetchModels = async () => {
  try {
    await store.dispatch('vehicleModels/get');
  } catch (error) {
    // Ignore Error
  }
};

const fetchLatestRate = async () => {
  try {
    await store.dispatch('exchangeRates/get');
    if (!latestRate.value) {
      await store.dispatch('exchangeRates/fetchCurrent');
    }
  } catch (error) {
    // Ignore Error
  }
};

watch(searchQuery, val => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    debouncedQuery.value = val;
    page.value = 1;
  }, 300);
});

watch(filterBrand, () => {
  filterModel.value = '';
  page.value = 1;
});

watch(filterModel, () => {
  page.value = 1;
});

onMounted(() => {
  fetchPrices();
  fetchBrands();
  fetchModels();
  fetchLatestRate();
});

const openAddPopup = () => {
  showAddPopup.value = true;
};

const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = price => {
  showEditPopup.value = true;
  activePrice.value = price;
};

const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openImportPopup = () => {
  showImportPopup.value = true;
};

const hideImportPopup = () => {
  showImportPopup.value = false;
};

const openDeletePopup = price => {
  showDeleteConfirmationPopup.value = true;
  activePrice.value = price;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deletePrice = async id => {
  try {
    await store.dispatch('vehiclePrices/delete', id);
    useAlert('Precio eliminado correctamente');
  } catch (error) {
    useAlert(error?.message || 'Error al eliminar precio');
  }
};

const confirmDeletion = () => {
  loading[activePrice.value.id] = true;
  closeDeletePopup();
  deletePrice(activePrice.value.id);
};

const refreshRate = async () => {
  try {
    await store.dispatch('exchangeRates/fetchCurrent');
    useAlert('Tasa BCV actualizada correctamente');
  } catch (error) {
    useAlert(error?.message || 'Error al obtener tasa BCV');
  }
};

const formatCurrency = value => {
  if (!value) return '—';
  return `$${Number(value).toFixed(2)}`;
};

const formatBs = value => {
  if (!value) return '—';
  return `Bs.${Number(value).toFixed(2)}`;
};

const deleteMessage = computed(() => `"${activePrice.value.description}"?`);

const tableHeaders = computed(() => [
  'Descripción',
  'Marca',
  'Modelo',
  'Variante',
  'USD',
  'Divisor',
  'Bs.',
  'Acciones',
]);

const goToPage = p => {
  page.value = Math.max(1, Math.min(p, totalPages.value));
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="'Cargando precios...'"
    :no-records-found="!records.length"
    :no-records-message="'No hay precios cargados'"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        title="Lista de Precios"
        description="Gestiona los precios de repuestos por marca y modelo"
        :search-placeholder="'Buscar por descripción...'"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ records.length }} precios
          </span>
        </template>
        <template #actions>
          <Button
            label="Actualizar Tasa BCV"
            size="sm"
            slate
            ghost
            icon="i-lucide-refresh-cw"
            class="mr-2"
            :is-loading="rateFlags.fetchingCurrent"
            @click="refreshRate"
          />
          <Button
            label="Importar CSV/Excel"
            size="sm"
            slate
            ghost
            icon="i-lucide-upload"
            class="mr-2"
            @click="openImportPopup"
          />
          <Button label="Nuevo Precio" size="sm" @click="openAddPopup" />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <!-- Tasa BCV banner -->
      <div
        class="flex items-center gap-3 px-4 py-2 mb-4 rounded-lg bg-n-alpha-2 text-n-slate-12"
      >
        <Icon class="size-5 text-n-brand-11" icon="i-lucide-banknote" />
        <template v-if="rateFlags.fetchingList || rateFlags.fetchingCurrent">
          <span class="text-sm text-n-slate-11 animate-pulse">
            Consultando tasa BCV...
          </span>
        </template>
        <template v-else-if="latestRate">
          <span class="text-sm font-medium">
            Tasa BCV: {{ formatCurrency(latestRate.rate) }} Bs/USD
          </span>
          <span class="text-xs text-n-slate-11">
            ({{ formatBs(latestRate.equiv_13) }} equiv. 13%)
          </span>
          <span class="text-xs text-n-slate-11">
            Actualizado: {{ latestRate.effective_date }}
          </span>
        </template>
        <template v-else>
          <span class="text-sm text-n-ruby-11">
            No hay tasa BCV disponible
          </span>
        </template>
      </div>

      <!-- Filters -->
      <div class="flex items-center gap-3 mb-4">
        <select v-model="filterBrand" class="text-sm">
          <option value="">Todas las marcas</option>
          <option v-for="brand in brands" :key="brand.id" :value="brand.id">
            {{ brand.name }}
          </option>
        </select>
        <select v-model="filterModel" class="text-sm">
          <option value="">Todos los modelos</option>
          <option v-for="m in filteredModels" :key="m.id" :value="m.id">
            {{ m.name }}
          </option>
        </select>
        <span v-if="filteredRecords.length" class="text-xs text-n-slate-11">
          {{ filteredRecords.length }} resultados
        </span>
      </div>

      <BaseTable
        :headers="tableHeaders"
        :items="pagedRecords"
        :no-data-message="
          !records.length
            ? 'No hay precios cargados'
            : searchQuery || filterBrand || filterModel
              ? 'Sin resultados'
              : ''
        "
      >
        <template #header-0>{{ tableHeaders[0] }}</template>
        <template #header-1>{{ tableHeaders[1] }}</template>
        <template #header-2>{{ tableHeaders[2] }}</template>
        <template #header-3>{{ tableHeaders[3] }}</template>
        <template #header-4>{{ tableHeaders[4] }}</template>
        <template #header-5>{{ tableHeaders[5] }}</template>
        <template #header-6>{{ tableHeaders[6] }}</template>
        <template #header-7>{{ tableHeaders[7] }}</template>

        <template #row="{ items }">
          <BaseTableRow v-for="price in items" :key="price.id" :item="price">
            <template #default>
              <BaseTableCell class="max-w-xs">
                <span class="text-sm text-n-slate-12 truncate block">
                  {{ price.description }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-24">
                <span
                  class="text-xs font-medium px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-12"
                >
                  {{ price.brand?.name || '—' }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-24">
                <span class="text-xs text-n-slate-11">
                  {{ price.model?.name || '—' }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-28">
                <span class="text-xs text-n-slate-11">
                  {{ price.variant || '—' }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-20">
                <span class="text-sm font-medium text-n-green-11">
                  {{ formatCurrency(price.cost_usd) }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-16">
                <span class="text-sm text-n-slate-11">
                  {{ price.divisor || '—' }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-24">
                <span class="text-sm text-n-blue-11">
                  {{ formatBs(calcCostBs(price.divisor)) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-24">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="'Editar'"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(price)"
                  />
                  <Button
                    v-tooltip.top="'Eliminar'"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[price.id]"
                    @click="openDeletePopup(price)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>

      <!-- Pagination -->
      <div
        v-if="totalPages > 1"
        class="flex items-center justify-between px-4 py-3 mt-2"
      >
        <span class="text-xs text-n-slate-11">
          Mostrando {{ (page - 1) * perPage + 1 }}-{{
            Math.min(page * perPage, filteredRecords.length)
          }}
          de {{ filteredRecords.length }}
        </span>
        <div class="flex items-center gap-1">
          <Button
            icon="i-lucide-chevron-left"
            size="sm"
            slate
            ghost
            :disabled="page <= 1"
            @click="goToPage(page - 1)"
          />
          <Button
            v-for="p in Math.min(totalPages, 7)"
            :key="p"
            size="sm"
            :label="String(p)"
            :class="p === page ? 'text-n-brand-11 font-bold' : 'text-n-slate-11'"
            slate
            ghost
            @click="goToPage(p)"
          />
          <Button
            v-if="totalPages > 7"
            size="sm"
            label="..."
            slate
            ghost
            disabled
          />
          <Button
            v-if="totalPages > 7"
            size="sm"
            :label="String(totalPages)"
            slate
            ghost
            :class="totalPages === page ? 'text-n-brand-11 font-bold' : 'text-n-slate-11'"
            @click="goToPage(totalPages)"
          />
          <Button
            icon="i-lucide-chevron-right"
            size="sm"
            slate
            ghost
            :disabled="page >= totalPages"
            @click="goToPage(page + 1)"
          />
        </div>
      </div>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddPrice :on-close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditPrice
        v-if="showEditPopup"
        :price="activePrice"
        :on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-modal v-model:show="showImportPopup" :on-close="hideImportPopup">
      <ImportPrices :on-close="hideImportPopup" />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      title="Eliminar Precio"
      message="¿Estás seguro de que quieres eliminar"
      :message-value="deleteMessage"
      confirm-text="Eliminar"
      reject-text="Cancelar"
    />
  </SettingsLayout>
</template>
