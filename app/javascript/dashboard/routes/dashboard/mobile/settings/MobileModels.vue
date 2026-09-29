<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import MobileHeader from '../components/MobileHeader.vue';
import AddModel from '../../settings/vehicles/Models/AddModel.vue';
import EditModel from '../../settings/vehicles/Models/EditModel.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const store = useStore();
const getters = useStoreGetters();

const showAdd = ref(false);
const editing = ref(null);

const brandId = computed(() => route.params.brandId);
const models = computed(() => getters['vehicleModels/getModels'].value);
const uiFlags = computed(() => getters['vehicleModels/getUIFlags'].value);
const brand = computed(() =>
  getters['vehicleBrands/getBrands'].value.find(
    b => b.id === Number(brandId.value)
  )
);
const brandsRoute = computed(() => ({
  name: 'mobile_brands',
  params: { accountId: route.params.accountId },
}));

watch(
  brandId,
  () => {
    store.dispatch('vehicleModels/get', { brandId: brandId.value });
    if (!brand.value) store.dispatch('vehicleBrands/get');
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader
      :title="$t('MOBILE.BRANDS.MODELS_TITLE', { brand: brand?.name || '' })"
      :back-to="brandsRoute"
    >
      <template #end>
        <Button
          icon="i-lucide-plus"
          size="sm"
          :aria-label="$t('MOBILE.BRANDS.ADD_MODEL')"
          @click="showAdd = true"
        />
      </template>
    </MobileHeader>
    <div class="flex flex-col flex-1 min-h-0 overflow-y-auto">
      <div
        v-for="model in models"
        :key="model.id"
        class="flex items-center gap-2 px-4 py-3 border-b border-n-weak"
      >
        <span class="flex-1 text-sm truncate text-n-slate-12">
          {{ model.name }}
        </span>
        <Button
          icon="i-lucide-pencil"
          variant="ghost"
          color="slate"
          size="sm"
          @click="editing = model"
        />
      </div>
      <div class="flex justify-center p-4">
        <Spinner v-if="uiFlags.fetchingList" />
        <p v-else-if="!models.length" class="text-sm text-n-slate-11">
          {{ $t('MOBILE.BRANDS.NO_MODELS') }}
        </p>
      </div>
    </div>

    <woot-modal v-model:show="showAdd" :on-close="() => (showAdd = false)">
      <AddModel :brand-id="brandId" :on-close="() => (showAdd = false)" />
    </woot-modal>
    <woot-modal :show="!!editing" :on-close="() => (editing = null)">
      <EditModel
        v-if="editing"
        :model="editing"
        :on-close="() => (editing = null)"
      />
    </woot-modal>
  </div>
</template>
