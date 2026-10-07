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
import { PRICE_KINDS, kindOf, isExpired } from './priceKinds';
import {
  calcCostBs as costBsFor,
  calcBolivares as bolivaresFor,
  toVE,
} from 'dashboard/helper/vehiclePriceHelper';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
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
const kind = ref('repuesto');
let debounceTimer = null;

const records = computed(() => getters['vehiclePrices/getPrices'].value);
const kindRecords = computed(() =>
  records.value.filter(p => kindOf(p) === kind.value)
);
const kindInfo = computed(() => PRICE_KINDS[kind.value]);
const isPartsTab = computed(() => kind.value === 'repuesto');

const kindKeys = Object.keys(PRICE_KINDS);
const kindTabs = computed(() =>
  kindKeys.map(key => ({
    key,
    label: PRICE_KINDS[key].tab,
    count: records.value.filter(p => kindOf(p) === key).length,
  }))
);
const activeTabIndex = computed(() => kindKeys.indexOf(kind.value));
const uiFlags = computed(() => getters['vehiclePrices/getUIFlags'].value);
const rateFlags = computed(() => getters['exchangeRates/getUIFlags'].value);
const brands = computed(() => getters['vehicleBrands/getBrands'].value);
const models = computed(() => getters['vehicleModels/getModels'].value);
const latestRate = computed(() => getters['exchangeRates/getLatestRate'].value);
const markupPercent = computed(
  () => getters['exchangeRates/getMarkupPercent'].value
);
const editingMarkup = ref(false);
const markupDraft = ref('');

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
  let items = kindRecords.value;

  if (filterBrand.value) {
    items = items.filter(p => p.brand?.id === Number(filterBrand.value));
  }
  if (filterModel.value) {
    items = items.filter(p => p.model?.id === Number(filterModel.value));
  }

  const query = debouncedQuery.value.trim();
  if (query) {
    items = picoSearch(items, query, [
      'description',
      'variant',
      'synonyms',
      'details',
    ]);
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

const calcCostBs = divisa => costBsFor(divisa, latestRate.value);
const calcBolivares = divisa => bolivaresFor(divisa, latestRate.value);

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

watch([filterModel, kind], () => {
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

// One click from the list: the store marks a part sold out far more often than it edits it.
const toggleAvailable = async price => {
  const available = !price.available;
  try {
    await store.dispatch('vehiclePrices/update', { id: price.id, available });
    useAlert(available ? 'Marcado como disponible' : 'Marcado como agotado');
  } catch (error) {
    useAlert(error?.message || 'Error al actualizar precio');
  }
};

// Bulk availability: select rows (or every filtered result) and mark them at once.
const selected = ref(new Set());

const allFilteredSelected = computed(
  () =>
    filteredRecords.value.length > 0 &&
    filteredRecords.value.every(p => selected.value.has(p.id))
);

const toggleSelected = id => {
  if (selected.value.has(id)) selected.value.delete(id);
  else selected.value.add(id);
};

const toggleSelectAll = () => {
  selected.value = allFilteredSelected.value
    ? new Set()
    : new Set(filteredRecords.value.map(p => p.id));
};

const selectAllLabel = computed(
  () => `Seleccionar los ${filteredRecords.value.length} resultados`
);

const clearSelection = () => {
  selected.value = new Set();
};

// A selection made under other filters would act on rows the user no longer sees.
watch([debouncedQuery, filterBrand, filterModel, kind], clearSelection);

const markSelected = async available => {
  const ids = [...selected.value];
  try {
    await store.dispatch('vehiclePrices/bulkAvailability', { ids, available });
    const done = available
      ? 'marcados como disponibles'
      : 'marcados como agotados';
    useAlert(`${ids.length} ${done}`);
    clearSelection();
  } catch (error) {
    useAlert(error?.message || 'Error al actualizar precios');
  }
};

const confirmDeletion = () => {
  loading[activePrice.value.id] = true;
  closeDeletePopup();
  deletePrice(activePrice.value.id);
};

// 13 -> "13", 13.5 -> "13,5"
const formatPercent = value => toVE(value, Number.isInteger(value) ? 0 : 1);

const rateSourceLabel = computed(() =>
  latestRate.value?.source === 'bcv.org.ve'
    ? 'fuente: BCV'
    : 'fuente: respaldo (el BCV no respondió)'
);

const startMarkupEdit = () => {
  markupDraft.value = String(markupPercent.value);
  editingMarkup.value = true;
};

// Saving reprices the whole list on the server; the rows here recompute from the new rate.
const saveMarkup = async () => {
  const percent = Number(String(markupDraft.value).replace(',', '.'));
  if (
    markupDraft.value === '' ||
    Number.isNaN(percent) ||
    percent < 0 ||
    percent > 100
  ) {
    useAlert('El porcentaje debe ser un número entre 0 y 100');
    return;
  }
  try {
    await store.dispatch('exchangeRates/updateMarkup', percent);
    editingMarkup.value = false;
    useAlert(
      `Porcentaje actualizado a ${formatPercent(percent)}%. Precios recalculados`
    );
  } catch (error) {
    useAlert(error?.message || 'No se pudo actualizar el porcentaje');
  }
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
  if (model || variant) return model || variant;
  return price.brand ? 'Todos los modelos' : 'Todas las marcas';
};

const formatBs = value => {
  if (!value) return '—';
  return `Bs. ${toVE(value, 2)}`;
};

const deleteMessage = computed(() => `"${activePrice.value.description}"?`);

const tableHeaders = computed(() => [
  'Seleccionar',
  kindInfo.value.column,
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
        description="Gestiona los precios de repuestos, combos y promociones por marca y modelo"
        search-placeholder="Buscar por descripción..."
      >
        <template v-if="kindRecords.length" #count>
          <span class="text-body-main text-n-slate-11 tabular-nums">
            {{ kindRecords.length.toLocaleString('es-VE') }}
            {{ kindInfo.count }}
          </span>
        </template>
        <template #actions>
          <Button
            v-if="isPartsTab"
            label="Importar CSV/Excel"
            size="sm"
            slate
            ghost
            icon="i-lucide-upload"
            class="mr-2"
            @click="openImportPopup"
          />
          <Button
            :label="kindInfo.newLabel"
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
              EQUIV. {{ formatPercent(markupPercent) }}%
            </span>
            <span class="text-base font-semibold tabular-nums">
              {{ formatBs(latestRate.equiv_13) }}
            </span>
          </div>
          <div v-if="editingMarkup" class="flex items-center gap-2">
            <input
              v-model="markupDraft"
              type="number"
              min="0"
              max="100"
              step="0.5"
              aria-label="Porcentaje sobre la tasa BCV"
              class="!mb-0 !h-8 !w-20 !px-2 !text-sm tabular-nums rounded-lg bg-n-alpha-black2 border border-n-weak text-n-slate-12"
              @keyup.enter="saveMarkup"
              @keyup.esc="editingMarkup = false"
            />
            <Button
              label="Guardar"
              size="sm"
              :is-loading="rateFlags.updatingMarkup"
              @click="saveMarkup"
            />
            <Button
              label="Cancelar"
              size="sm"
              slate
              link
              :disabled="rateFlags.updatingMarkup"
              @click="editingMarkup = false"
            />
          </div>
          <Button
            v-else
            label="Cambiar porcentaje"
            size="sm"
            link
            icon="i-lucide-pencil"
            @click="startMarkupEdit"
          />
          <span class="text-xs text-n-slate-11">
            Fecha valor {{ formatDate(latestRate.effective_date) }} ·
            {{ rateSourceLabel }} · se revisa sola cada hora
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

      <TabBar
        class="mb-4"
        :tabs="kindTabs"
        :initial-active-tab="activeTabIndex"
        @tab-changed="tab => (kind = tab.key)"
      />

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

      <div
        v-if="selected.size"
        class="flex flex-wrap items-center gap-3 px-4 py-2 mb-4 rounded-xl bg-n-alpha-2"
      >
        <span class="text-sm font-medium text-n-slate-12 tabular-nums">
          {{ selected.size.toLocaleString('es-VE') }} seleccionados
        </span>
        <Button
          label="Marcar agotados"
          size="sm"
          ruby
          faded
          icon="i-lucide-package-x"
          :is-loading="uiFlags.updatingItem"
          @click="markSelected(false)"
        />
        <Button
          label="Marcar disponibles"
          size="sm"
          teal
          faded
          icon="i-lucide-package-check"
          :is-loading="uiFlags.updatingItem"
          @click="markSelected(true)"
        />
        <Button
          label="Quitar selección"
          size="sm"
          slate
          link
          class="ltr:ml-auto rtl:mr-auto"
          @click="clearSelection"
        />
      </div>

      <BaseTable
        :headers="tableHeaders"
        :items="pagedRecords"
        :no-data-message="
          !kindRecords.length
            ? kindInfo.empty
            : searchQuery || filterBrand || filterModel
              ? 'Sin resultados'
              : ''
        "
      >
        <template #header-0>
          <input
            v-tooltip.top="selectAllLabel"
            type="checkbox"
            class="!w-auto !mb-0"
            :aria-label="selectAllLabel"
            :checked="allFilteredSelected"
            @change="toggleSelectAll"
          />
        </template>
        <template #header-1>{{ tableHeaders[1] }}</template>
        <template #header-2>{{ tableHeaders[2] }}</template>
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
          <span class="block text-end">{{ tableHeaders[6] }}</span>
        </template>
        <template #header-7>
          <span class="sr-only">{{ tableHeaders[7] }}</span>
        </template>

        <template #row="{ items }">
          <BaseTableRow v-for="price in items" :key="price.id" :item="price">
            <template #default>
              <BaseTableCell class="w-8">
                <input
                  type="checkbox"
                  class="!w-auto !mb-0"
                  :aria-label="price.description"
                  :checked="selected.has(price.id)"
                  @change="toggleSelected(price.id)"
                />
              </BaseTableCell>
              <BaseTableCell class="min-w-56">
                <div class="flex flex-col gap-1.5">
                  <span
                    class="text-sm font-medium text-n-slate-12 whitespace-normal"
                  >
                    {{ price.description }}
                    <span
                      v-if="!price.available"
                      class="px-1.5 py-px ltr:ml-1 rtl:mr-1 rounded-full bg-n-ruby-3 text-[11px] font-semibold text-n-ruby-11"
                    >
                      Agotado
                    </span>
                    <span
                      v-if="isExpired(price)"
                      class="px-1.5 py-px ltr:ml-1 rtl:mr-1 rounded-full bg-n-amber-3 text-[11px] font-semibold text-n-amber-11"
                    >
                      Vencida
                    </span>
                  </span>
                  <span
                    v-if="price.details"
                    class="text-xs text-n-slate-11 whitespace-normal"
                  >
                    {{ price.details }}
                  </span>
                  <span v-if="price.ends_on" class="text-xs text-n-slate-11">
                    Hasta el {{ formatDate(price.ends_on) }}
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
                    {{ price.brand?.name || 'TODAS' }}
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

              <BaseTableCell align="end" class="w-32">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="
                      price.available ? 'Marcar agotado' : 'Marcar disponible'
                    "
                    :icon="
                      price.available
                        ? 'i-lucide-package-x'
                        : 'i-lucide-package-check'
                    "
                    slate
                    sm
                    @click="toggleAvailable(price)"
                  />
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
      <AddPrice :kind="kind" :on-close="hideAddPopup" />
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
