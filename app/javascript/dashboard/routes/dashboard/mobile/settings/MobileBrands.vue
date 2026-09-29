<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import MobileHeader from '../components/MobileHeader.vue';
import AddBrand from '../../settings/vehicles/AddBrand.vue';
import EditBrand from '../../settings/vehicles/EditBrand.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const store = useStore();
const getters = useStoreGetters();

const showAdd = ref(false);
const editing = ref(null);

const brands = computed(() => getters['vehicleBrands/getBrands'].value);
const uiFlags = computed(() => getters['vehicleBrands/getUIFlags'].value);
const settingsRoute = computed(() => ({
  name: 'mobile_settings',
  params: { accountId: route.params.accountId },
}));

onMounted(() => store.dispatch('vehicleBrands/get'));
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <MobileHeader :title="$t('MOBILE.BRANDS.TITLE')" :back-to="settingsRoute">
      <template #end>
        <Button
          icon="i-lucide-plus"
          size="sm"
          :aria-label="$t('MOBILE.BRANDS.ADD')"
          @click="showAdd = true"
        />
      </template>
    </MobileHeader>
    <div class="flex flex-col flex-1 min-h-0 overflow-y-auto">
      <div
        v-for="brand in brands"
        :key="brand.id"
        class="flex items-center border-b border-n-weak"
      >
        <router-link
          :to="{
            name: 'mobile_models',
            params: { accountId: route.params.accountId, brandId: brand.id },
          }"
          class="flex flex-col flex-1 min-w-0 px-4 py-3 active:bg-n-alpha-2"
        >
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ brand.name }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ $t('MOBILE.BRANDS.MODELS', { count: brand.models_count || 0 }) }}
          </span>
        </router-link>
        <Button
          icon="i-lucide-pencil"
          variant="ghost"
          color="slate"
          size="sm"
          class="me-2"
          @click="editing = brand"
        />
        <Icon
          icon="i-lucide-chevron-right"
          class="size-4 me-3 text-n-slate-10"
        />
      </div>
      <div class="flex justify-center p-4">
        <Spinner v-if="uiFlags.fetchingList" />
        <p v-else-if="!brands.length" class="text-sm text-n-slate-11">
          {{ $t('MOBILE.BRANDS.EMPTY') }}
        </p>
      </div>
    </div>

    <woot-modal v-model:show="showAdd" :on-close="() => (showAdd = false)">
      <AddBrand :on-close="() => (showAdd = false)" />
    </woot-modal>
    <woot-modal :show="!!editing" :on-close="() => (editing = null)">
      <EditBrand
        v-if="editing"
        :brand="editing"
        :on-close="() => (editing = null)"
      />
    </woot-modal>
  </div>
</template>
