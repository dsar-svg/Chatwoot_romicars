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
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
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
  return models.value.filter(m => m.brand?.id === Number(filterBrand.value));
});

const brandOptions = computed(() => [
  { value: '', label: 'Todas las marcas' },
  ...brands.value.map(b => ({ value: b.id, label: b.name })),
]);

const modelOptions = computed(() => [
  { value: '', label: 'Todos los modelos' },
  ...filteredModels.value.map(m => ({ value: m.id, label: m.name })),
]);

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
    items = picoSearch(items, query, ['description', 'variant', 'synonyms']);
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

const calcCostBs = divisa => {
  if (!divisa || !latestRate.value) return null;
  return Number((divisa * latestRate.value.equiv_13).toFixed(2));
};

const calcBolivares = divisa => {
  const montoBs = calcCostBs(divisa);
  if (montoBs === null) return null;
  const tasaBcv = latestRate.value.equiv_13 / 1.13;
  return Math.round(montoBs / tasaBcv);
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

const toVE = (value, decimals) =>
  Number(value).toLocaleString('es-VE', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });

const formatCurrency = value => {
  if (!value) return '—';
  return `${toVE(value, 2)}`;
};

const formatUsd = value => {
  if (!value) return '—';
  return `${toVE(value, 0)}`;
};

const formatDate = value => (value ? value.split('-').reverse().join('/') : '');

const synonymsOf = price =>
  (price.synonyms || '')
    .split(',')
    .map(word => word.trim())
    .filter(Boolean);

const compact = text => text.replace(/\s/g, '').toUpperCase();

const vehicleDetail = price => {
  const model = price.model?.name;
  const variant = price.variant;
  if (model && variant && compact(variant) !== compact(model)) {
    return `${model} · ${variant}`;
  }
  return model || variant || 'Todos los modelos';
};

const formatBs = value => {
  if (!value) return '—';
  return `Bs. ${toVE(value, 2)}`;
};

const deleteMessage = computed(() => `"${activePrice.value.description}"?`);

const tableHeaders = computed(() => [
  'Repuesto',
  'Vehículo',
  'Costo USD',
  'Divisa',
  'Bolívares',
  'Monto Bs',
  'Acciones',
]);

const goToPage = p => {
  page.value = Math.max(1, Math.min(p, totalPages.value));
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    loading-message="Cargando precios..."
    :no-records-found="!records.length"
    no-records-message="No hay precios cargados"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        title="Lista de Precios"
        description="Gestiona los precios de repuestos por marca y modelo"
        search-placeholder="Buscar por descripción..."
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11 tabular-nums">
            {{ records.length.toLocaleString('es-VE') }} repuestos
          </span>
        </template>
        <template #actions>
          <Button
            label="Importar CSV/Excel"
            size="sm"
            slate
            ghost
            icon="i-lucide-upload"
            class="mr-2"
            @click="openImportPopup"
          />
          <Button
            label="Nuevo Precio"
            size="sm"
            icon="i-lucide-plus"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <!-- Tasa BCV banner -->
      <div
        class="flex flex-wrap items-center gap-x-7 gap-y-3 px-4 py-3 mb-4 rounded-xl bg-n-blue-2 border border-n-blue-4 text-n-slate-12"
      >
        <div class="flex items-center gap-2.5">
          <span
            class="size-8 rounded-lg bg-n-brand grid place-items-center flex-shrink-0"
          >
            <Icon class="size-4 text-white" icon="i-lucide-banknote" />
          </span>
          <span
            v-if="rateFlags.fetchingList || rateFlags.fetchingCurrent"
            class="text-sm text-n-slate-11 animate-pulse"
          >
            Consultando tasa BCV...
          </span>
          <div v-else-if="latestRate" class="flex flex-col">
            <span
              class="text-[11px] font-semibold tracking-widest text-n-slate-11"
            >
              TASA BCV
            </span>
            <span class="text-base font-semibold tabular-nums">
              {{ formatBs(latestRate.rate) }}
              <span class="text-xs font-normal text-n-slate-11">/ USD</span>
            </span>
          </div>
          <span v-else class="text-sm text-n-ruby-11">
            No hay tasa BCV disponible
          </span>
        </div>
        <template
          v-if="
            latestRate && !rateFlags.fetchingList && !rateFlags.fetchingCurrent
          "
        >
          <div class="flex flex-col">
            <span
              class="text-[11px] font-semibold tracking-widest text-n-slate-11"
            >
              EQUIV. 13%
            </span>
            <span class="text-base font-semibold tabular-nums">
              {{ formatBs(latestRate.equiv_13) }}
            </span>
          </div>
          <span class="text-xs text-n-slate-11">
            Actualizada {{ formatDate(latestRate.effective_date) }} · se
            recalcula sola cada 6 horas
          </span>
        </template>
        <Button
          label="Actualizar ahora"
          size="sm"
          link
          icon="i-lucide-refresh-cw"
          class="ltr:ml-auto rtl:mr-auto"
          :is-loading="rateFlags.fetchingCurrent"
          @click="refreshRate"
        />
      </div>

      <!-- Filters -->
      <div class="flex items-center gap-3 mb-4">
        <ComboBox
          v-model="filterBrand"
          class="!w-56"
          :options="brandOptions"
          placeholder="Todas las marcas"
          search-placeholder="Buscar marca..."
          empty-state="Sin marcas"
        />
        <ComboBox
          v-model="filterModel"
          class="!w-56"
          :options="modelOptions"
          :disabled="!filterBrand"
          placeholder="Todos los modelos"
          search-placeholder="Buscar modelo..."
          empty-state="Sin modelos"
        />
        <span
          v-if="filteredRecords.length"
          class="ltr:ml-auto rtl:mr-auto text-xs text-n-slate-11 tabular-nums whitespace-nowrap"
        >
          {{ filteredRecords.length.toLocaleString('es-VE') }} resultados
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
        <template #header-2>
          <span class="block text-end">{{ tableHeaders[2] }}</span>
        </template>
        <template #header-3>
          <span class="block text-end">{{ tableHeaders[3] }}</span>
        </template>
        <template #header-4>
          <span class="block text-end">{{ tableHeaders[4] }}</span>
        </template>
        <template #header-5>
          <span class="block text-end">{{ tableHeaders[5] }}</span>
        </template>
        <template #header-6>
          <span class="sr-only">{{ tableHeaders[6] }}</span>
        </template>

        <template #row="{ items }">
          <BaseTableRow v-for="price in items" :key="price.id" :item="price">
            <template #default>
              <BaseTableCell class="min-w-56">
                <div class="flex flex-col gap-1.5">
                  <span
                    class="text-sm font-medium text-n-slate-12 whitespace-normal"
                  >
                    {{ price.description }}
                  </span>
                  <div
                    v-if="synonymsOf(price).length"
                    class="flex flex-wrap gap-1"
                  >
                    <span
                      v-for="word in synonymsOf(price).slice(0, 3)"
                      :key="word"
                      class="px-1.5 py-px rounded-full bg-n-alpha-2 text-[11px] text-n-slate-11"
                    >
                      {{ word }}
                    </span>
                    <span
                      v-if="synonymsOf(price).length > 3"
                      v-tooltip.top="synonymsOf(price).slice(3).join(', ')"
                      class="px-1.5 py-px rounded-full bg-n-alpha-2 text-[11px] text-n-slate-11"
                    >
                      +{{ synonymsOf(price).length - 3 }}
                    </span>
                  </div>
                </div>
              </BaseTableCell>

              <BaseTableCell class="w-56">
                <div class="flex items-center gap-2 min-w-0">
                  <span
                    class="px-2 py-0.5 rounded-md bg-n-blue-3 text-n-blue-11 text-xs font-semibold tracking-wide whitespace-nowrap"
                  >
                    {{ price.brand?.name || '—' }}
                  </span>
                  <span class="text-xs text-n-slate-11 truncate">
                    {{ vehicleDetail(price) }}
                  </span>
                </div>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-24">
                <span class="text-sm text-n-slate-11 tabular-nums">
                  {{ formatCurrency(price.cost_usd) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-20">
                <span class="text-sm text-n-slate-12 tabular-nums">
                  {{ formatUsd(price.divisa) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-24">
                <span class="text-sm text-n-slate-12 tabular-nums">
                  {{ formatUsd(calcBolivares(price.divisa)) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-32">
                <span
                  class="text-sm font-semibold text-n-slate-12 tabular-nums whitespace-nowrap"
                >
                  {{ formatBs(calcCostBs(price.divisa)) }}
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
            :class="
              p === page
                ? '!bg-n-brand !text-white font-semibold'
                : 'text-n-slate-11'
            "
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
            :class="
              totalPages === page
                ? '!bg-n-brand !text-white font-semibold'
                : 'text-n-slate-11'
            "
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
