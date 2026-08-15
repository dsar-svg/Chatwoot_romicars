<script setup>
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useRoute, useRouter } from 'vue-router';
import AddModel from './AddModel.vue';
import EditModel from './EditModel.vue';

import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({
  name: 'VehicleModelSettings',
});

const getters = useStoreGetters();
const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activeModel = ref({});
const loading = ref({});

const brandId = computed(() => route.params.brandId);
const records = computed(() => getters['vehicleModels/getModels'].value);
const uiFlags = computed(() => getters['vehicleModels/getUIFlags'].value);
const brands = computed(() => getters['vehicleBrands/getBrands'].value);

const currentBrand = computed(() =>
  brands.value.find(b => b.id === Number(brandId.value))
);

const fetchModels = async () => {
  try {
    await store.dispatch('vehicleModels/get', { brandId: brandId.value });
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

onMounted(() => {
  fetchBrands();
  fetchModels();
});

watch(brandId, () => {
  fetchModels();
});

const openAddPopup = () => {
  showAddPopup.value = true;
};

const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = model => {
  showEditPopup.value = true;
  activeModel.value = model;
};

const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = model => {
  showDeleteConfirmationPopup.value = true;
  activeModel.value = model;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteModel = async id => {
  try {
    await store.dispatch('vehicleModels/delete', id);
    useAlert('Modelo eliminado correctamente');
  } catch (error) {
    useAlert(error?.message || 'Error al eliminar modelo');
  }
};

const confirmDeletion = () => {
  loading[activeModel.value.id] = true;
  closeDeletePopup();
  deleteModel(activeModel.value.id);
};

const goBack = () => {
  router.push({ name: 'vehicle_brands_list' });
};

const deleteMessage = computed(() => `"${activeModel.value.name}"?`);

const tableHeaders = computed(() => ['Modelo', 'Acciones']);
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="'Cargando modelos...'"
    :no-records-found="!records.length"
    :no-records-message="'No hay modelos creados'"
  >
    <template #header>
      <BaseSettingsHeader
        :title="`Modelos - ${currentBrand?.name || ''}`"
        description="Gestiona los modelos de esta marca"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ records.length }} Modelos
          </span>
        </template>
        <template #actions>
          <Button
            label="Volver"
            size="sm"
            slate
            ghost
            icon="i-lucide-arrow-left"
            class="mr-2"
            @click="goBack"
          />
          <Button label="Nuevo Modelo" size="sm" @click="openAddPopup" />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="records"
        :no-data-message="'No hay modelos creados'"
      >
        <template #header-0>{{ tableHeaders[0] }}</template>
        <template #header-1>{{ tableHeaders[1] }}</template>

        <template #row="{ items }">
          <BaseTableRow v-for="model in items" :key="model.id" :item="model">
            <template #default>
              <BaseTableCell class="max-w-0">
                <span class="text-heading-3 text-n-slate-12">
                  {{ model.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-24">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="'Editar'"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(model)"
                  />
                  <Button
                    v-tooltip.top="'Eliminar'"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[model.id]"
                    @click="openDeletePopup(model)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddModel
        :brand-id="brandId"
        :on-close="hideAddPopup"
      />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditModel
        v-if="showEditPopup"
        :model="activeModel"
        :on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      title="Eliminar Modelo"
      message="¿Estás seguro de que quieres eliminar"
      :message-value="deleteMessage"
      confirm-text="Eliminar"
      reject-text="Cancelar"
    />
  </SettingsLayout>
</template>
