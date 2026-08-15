<script setup>
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
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
const { t } = useI18n();

const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showImportPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activePrice = ref({});
const loading = ref({});
const searchQuery = ref('');
const filterBrand = ref('');
const filterModel = ref('');

const records = computed(() => getters['vehiclePrices/getPrices'].value);
const uiFlags = computed(() => getters['vehiclePrices/getUIFlags'].value);
const brands = computed(() => getters['vehicleBrands/getBrands'].value);
const latestRate = computed(() => getters['exchangeRates/getLatestRate'].value);

const filteredRecords = computed(() => {
  let items = records.value;

  if (filterBrand.value) {
    items = items.filter(p => p.brand?.id === Number(filterBrand.value));
  }
  if (filterModel.value) {
    items = items.filter(p => p.model?.id === Number(filterModel.value));
  }

  const query = searchQuery.value.trim();
  if (query) {
    items = picoSearch(items, query, ['description', 'variant']);
  }

  return items;
});

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

const fetchLatestRate = async () => {
  try {
    await store.dispatch('exchangeRates/get');
  } catch (error) {
    // Ignore Error
  }
};

const refreshRate = async () => {
  try {
    await store.dispatch('exchangeRates/fetchCurrent');
    useAlert('Tasa BCV actualizada correctamente');
    await fetchPrices();
  } catch (error) {
    useAlert(error?.message || 'Error al obtener tasa BCV');
  }
};

onMounted(() => {
  fetchPrices();
  fetchBrands();
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
            v-if="latestRate"
            label="Actualizar Tasa BCV"
            size="sm"
            slate
            ghost
            icon="i-lucide-refresh-cw"
            class="mr-2"
            :is-loading="uiFlags.fetchingCurrent"
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
        v-if="latestRate"
        class="flex items-center gap-3 px-4 py-2 mb-4 rounded-lg bg-n-alpha-2 text-n-slate-12"
      >
        <Icon class="size-5 text-n-brand-11" icon="i-lucide-banknote" />
        <span class="text-sm font-medium">
          Tasa BCV: {{ formatCurrency(latestRate.rate) }} Bs/USD
        </span>
        <span class="text-xs text-n-slate-11">
          ({{ formatBs(latestRate.equiv_13) }} equiv. 13%)
        </span>
        <span class="text-xs text-n-slate-11">
          Actualizado: {{ latestRate.effective_date }}
        </span>
      </div>

      <!-- Filters -->
      <div class="flex items-center gap-3 mb-4">
        <select v-model="filterBrand" class="text-sm">
          <option value="">Todas las marcas</option>
          <option v-for="brand in brands" :key="brand.id" :value="brand.id">
            {{ brand.name }}
          </option>
        </select>
      </div>

      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          !records.length
            ? 'No hay precios cargados'
            : searchQuery
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
                <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-12">
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
                  {{ formatBs(price.cost_bs) }}
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
