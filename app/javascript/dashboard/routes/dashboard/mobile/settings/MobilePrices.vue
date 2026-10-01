<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useDebounce } from '@vueuse/core';
import { picoSearch } from '@scmmishra/pico-search';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { calcBolivares, toVE } from 'dashboard/helper/vehiclePriceHelper';
import MobileHeader from '../components/MobileHeader.vue';
import AddPrice from '../../settings/prices/AddPrice.vue';
import EditPrice from '../../settings/prices/EditPrice.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const PAGE_SIZE = 50;

const route = useRoute();
const store = useStore();
const getters = useStoreGetters();

const query = ref('');
const debouncedQuery = useDebounce(query, 300);
const brandId = ref('');
const modelId = ref('');
const visible = ref(PAGE_SIZE);
const showAdd = ref(false);
const editing = ref(null);

const prices = computed(() => getters['vehiclePrices/getPrices'].value);
const uiFlags = computed(() => getters['vehiclePrices/getUIFlags'].value);
const brands = computed(() => getters['vehicleBrands/getBrands'].value);
const models = computed(() =>
  getters['vehicleModels/getModels'].value.filter(
    model => model.brand?.id === Number(brandId.value)
  )
);
const rate = computed(() => getters['exchangeRates/getLatestRate'].value);

const filtered = computed(() => {
  let items = prices.value;
  if (brandId.value) {
    items = items.filter(p => p.brand?.id === Number(brandId.value));
  }
  if (modelId.value) {
    items = items.filter(p => p.model?.id === Number(modelId.value));
  }
  const term = debouncedQuery.value.trim();
  return term
    ? picoSearch(items, term, ['description', 'variant', 'synonyms'])
    : items;
});
const shown = computed(() => filtered.value.slice(0, visible.value));

const settingsRoute = computed(() => ({
  name: 'mobile_settings',
  params: { accountId: route.params.accountId },
}));

const vehicleOf = price =>
  [price.brand?.name, price.model?.name, price.variant]
    .filter(Boolean)
    .join(' · ');
const usd = value => (value ? `${toVE(value, 0)}$` : '—');

watch([debouncedQuery, brandId, modelId], () => {
  visible.value = PAGE_SIZE;
});
watch(brandId, () => {
  modelId.value = '';
});

// Same data the settings price list loads.
onMounted(async () => {
  store.dispatch('vehiclePrices/get');
  store.dispatch('vehicleBrands/get');
  store.dispatch('vehicleModels/get');
  await store.dispatch('exchangeRates/get');
  if (!rate.value) store.dispatch('exchangeRates/fetchCurrent');
});
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader
      :title="$t('MOBILE.PRICES.TITLE')"
      :subtitle="
        rate ? `${$t('MOBILE.PRICES.BCV')}: Bs. ${toVE(rate.rate, 2)}` : ''
      "
      :back-to="settingsRoute"
    >
      <template #end>
        <Button
          icon="i-lucide-plus"
          size="sm"
          :aria-label="$t('MOBILE.PRICES.ADD')"
          @click="showAdd = true"
        />
      </template>
    </MobileHeader>
    <div
      class="flex flex-col flex-shrink-0 gap-2 px-3 py-2 border-b border-n-weak"
    >
      <input
        v-model="query"
        type="search"
        :placeholder="$t('MOBILE.PRICES.SEARCH')"
        class="w-full mb-0 text-sm rounded-lg"
      />
      <div class="flex gap-2">
        <select
          v-model="brandId"
          class="flex-1 h-9 py-0 mb-0 text-sm rounded-lg"
        >
          <option value="">{{ $t('MOBILE.PRICES.ALL_BRANDS') }}</option>
          <option v-for="brand in brands" :key="brand.id" :value="brand.id">
            {{ brand.name }}
          </option>
        </select>
        <select
          v-model="modelId"
          :disabled="!brandId"
          class="flex-1 h-9 py-0 mb-0 text-sm rounded-lg"
        >
          <option value="">{{ $t('MOBILE.PRICES.ALL_MODELS') }}</option>
          <option v-for="model in models" :key="model.id" :value="model.id">
            {{ model.name }}
          </option>
        </select>
      </div>
      <span class="text-xs text-n-slate-10">
        {{ $t('MOBILE.PRICES.COUNT', { count: filtered.length }) }}
      </span>
    </div>
    <div class="flex flex-col flex-1 min-h-0 overflow-y-auto">
      <button
        v-for="price in shown"
        :key="price.id"
        type="button"
        class="flex items-start gap-3 px-4 py-3 border-b border-n-weak text-start active:bg-n-alpha-2"
        @click="editing = price"
      >
        <div class="flex flex-col flex-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ price.description }}
          </span>
          <span
            v-if="!price.available"
            class="text-xs font-semibold text-n-ruby-11"
          >
            {{ $t('MOBILE.PRICES.SOLD_OUT') }}
          </span>
          <span class="text-xs truncate text-n-slate-11">
            {{ vehicleOf(price) }}
          </span>
        </div>
        <div class="flex flex-col items-end flex-shrink-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ usd(price.divisa) }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ $t('MOBILE.PRICES.BCV') }}:
            {{ usd(calcBolivares(price.divisa, rate)) }}
          </span>
        </div>
      </button>
      <div class="flex justify-center p-4">
        <Spinner v-if="uiFlags.fetchingList" />
        <p v-else-if="!filtered.length" class="text-sm text-n-slate-11">
          {{ $t('MOBILE.PRICES.EMPTY') }}
        </p>
        <Button
          v-else-if="shown.length < filtered.length"
          :label="$t('MOBILE.LOAD_MORE')"
          variant="faded"
          color="slate"
          size="sm"
          @click="visible += PAGE_SIZE"
        />
      </div>
    </div>

    <woot-modal v-model:show="showAdd" :on-close="() => (showAdd = false)">
      <AddPrice :on-close="() => (showAdd = false)" />
    </woot-modal>
    <woot-modal :show="!!editing" :on-close="() => (editing = null)">
      <EditPrice
        v-if="editing"
        :price="editing"
        :on-close="() => (editing = null)"
      />
    </woot-modal>
  </div>
</template>
