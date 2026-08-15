<script setup>
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import AddBrand from './AddBrand.vue';
import EditBrand from './EditBrand.vue';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({
  name: 'VehicleBrandSettings',
});

const getters = useStoreGetters();
const store = useStore();
const router = useRouter();
const { t } = useI18n();

const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activeBrand = ref({});
const loading = ref({});

const records = computed(() => getters['vehicleBrands/getBrands'].value);
const uiFlags = computed(() => getters['vehicleBrands/getUIFlags'].value);

const fetchBrands = async () => {
  try {
    await store.dispatch('vehicleBrands/get');
  } catch (error) {
    // Ignore Error
  }
};

onMounted(() => {
  fetchBrands();
});

const openAddPopup = () => {
  showAddPopup.value = true;
};

const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = brand => {
  showEditPopup.value = true;
  activeBrand.value = brand;
};

const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = brand => {
  showDeleteConfirmationPopup.value = true;
  activeBrand.value = brand;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteBrand = async id => {
  try {
    await store.dispatch('vehicleBrands/delete', id);
    useAlert('Marca eliminada correctamente');
  } catch (error) {
    useAlert(error?.message || 'Error al eliminar marca');
  }
};

const confirmDeletion = () => {
  loading[activeBrand.value.id] = true;
  closeDeletePopup();
  deleteBrand(activeBrand.value.id);
};

const goToModels = brand => {
  router.push({
    name: 'vehicle_models_list',
    params: { brandId: brand.id },
  });
};

const deleteMessage = computed(() => `"${activeBrand.value.name}"?`);

const tableHeaders = computed(() => ['Marca', 'Modelos', 'Precios', 'Acciones']);
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="'Cargando marcas...'"
    :no-records-found="!records.length"
    :no-records-message="'No hay marcas creadas'"
  >
    <template #header>
      <BaseSettingsHeader
        title="Marcas y Modelos"
        description="Gestiona las marcas y modelos de vehículos que maneja RomiCars"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ records.length }} Marcas
          </span>
        </template>
        <template #actions>
          <Button label="Nueva Marca" size="sm" @click="openAddPopup" />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="records"
        :no-data-message="'No hay marcas creadas'"
      >
        <template #header-0>{{ tableHeaders[0] }}</template>
        <template #header-1>{{ tableHeaders[1] }}</template>
        <template #header-2>{{ tableHeaders[2] }}</template>
        <template #header-3>{{ tableHeaders[3] }}</template>

        <template #row="{ items }">
          <BaseTableRow v-for="brand in items" :key="brand.id" :item="brand">
            <template #default>
              <BaseTableCell class="max-w-0">
                <span class="text-heading-3 text-n-slate-12">
                  {{ brand.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-24">
                <span class="text-sm text-n-slate-11">
                  {{ brand.models_count }} modelos
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-24">
                <span class="text-sm text-n-slate-11">
                  {{ brand.prices_count }} precios
                </span>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-48">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="'Ver Modelos'"
                    icon="i-lucide-list"
                    slate
                    sm
                    @click="goToModels(brand)"
                  />
                  <Button
                    v-tooltip.top="'Editar'"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(brand)"
                  />
                  <Button
                    v-tooltip.top="'Eliminar'"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[brand.id]"
                    @click="openDeletePopup(brand)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddBrand :on-close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditBrand
        v-if="showEditPopup"
        :brand="activeBrand"
        :on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      title="Eliminar Marca"
      message="¿Estás seguro de que quieres eliminar"
      :message-value="deleteMessage"
      confirm-text="Eliminar"
      reject-text="Cancelar"
    />
  </SettingsLayout>
</template>
