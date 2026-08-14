<script setup>
import { useAlert } from 'dashboard/composables';
import AddFaq from './AddFaq.vue';
import EditFaq from './EditFaq.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({
  name: 'FaqSettings',
});

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const showAddPopup = ref(false);
const loading = ref({});
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activeFaq = ref({});

const sortOrder = ref('asc');
const searchQuery = ref('');

const records = computed(() => getters['faqs/getFaqs'].value);

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, ['question', 'answer', 'keywords']);
});

const uiFlags = computed(() => getters['faqs/getUIFlags'].value);

const deleteMessage = computed(() => `"${activeFaq.value.question}"?`);

const toggleSort = () => {
  sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
};

const sortedRecords = computed(() => {
  const items = [...filteredRecords.value];
  return items.sort((a, b) => {
    const cmp = (a.question || '').localeCompare(b.question || '');
    return sortOrder.value === 'asc' ? cmp : -cmp;
  });
});

const fetchFaqs = async () => {
  try {
    await store.dispatch('faqs/get');
  } catch (error) {
    // Ignore Error
  }
};

onMounted(() => {
  fetchFaqs();
});

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = faq => {
  showEditPopup.value = true;
  activeFaq.value = faq;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = faq => {
  showDeleteConfirmationPopup.value = true;
  activeFaq.value = faq;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteFaq = async id => {
  try {
    await store.dispatch('faqs/delete', id);
    useAlert('FAQ eliminada correctamente');
  } catch (error) {
    useAlert(error?.message || 'Error al eliminar FAQ');
  }
};

const confirmDeletion = () => {
  loading[activeFaq.value.id] = true;
  closeDeletePopup();
  deleteFaq(activeFaq.value.id);
};

const categoryLabel = category => {
  const labels = {
    repuestos: 'Repuestos',
    envios: 'Envíos',
    garantias: 'Garantías',
    pagos: 'Pagos',
    general: 'General',
  };
  return labels[category] || category || '—';
};

const tableHeaders = computed(() => [
  'Pregunta',
  'Categoría',
  'Activa',
  'Acciones',
]);
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="'Cargando FAQs...'"
    :no-records-found="!records.length"
    :no-records-message="'No hay FAQs creadas'"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        title="FAQs"
        description="Gestiona las preguntas frecuentes que el bot usará para responder a los clientes"
        :search-placeholder="'Buscar FAQs...'"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ records.length }} FAQs
          </span>
        </template>
        <template #actions>
          <Button label="Nueva FAQ" size="sm" @click="openAddPopup" />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="sortedRecords"
        :no-data-message="
          !records.length
            ? 'No hay FAQs creadas'
            : searchQuery
              ? 'Sin resultados'
              : ''
        "
      >
        <template #header-0>
          <button
            class="flex items-center gap-2 p-0 cursor-pointer"
            @click="toggleSort"
          >
            <span class="mb-0">{{ tableHeaders[0] }}</span>
            <Icon
              class="size-5 text-n-slate-11 flex-shrink-0"
              :icon="
                sortOrder === 'desc'
                  ? 'i-woot-sort-descending'
                  : 'i-woot-sort-ascending'
              "
            />
          </button>
        </template>
        <template #header-1>{{ tableHeaders[1] }}</template>
        <template #header-2>{{ tableHeaders[2] }}</template>
        <template #header-3>{{ tableHeaders[3] }}</template>

        <template #row="{ items }">
          <BaseTableRow v-for="faq in items" :key="faq.id" :item="faq">
            <template #default>
              <BaseTableCell class="max-w-0">
                <div class="flex flex-col gap-1 min-w-0">
                  <span class="text-heading-3 text-n-slate-12 truncate block">
                    {{ faq.question }}
                  </span>
                  <p class="text-body-main text-n-slate-11 line-clamp-2">
                    {{ faq.answer }}
                  </p>
                </div>
              </BaseTableCell>

              <BaseTableCell class="w-28">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-n-alpha-2 text-n-slate-12"
                >
                  {{ categoryLabel(faq.category) }}
                </span>
              </BaseTableCell>

              <BaseTableCell class="w-16">
                <span
                  :class="
                    faq.active
                      ? 'text-n-green-11'
                      : 'text-n-slate-11'
                  "
                  class="text-sm"
                >
                  {{ faq.active ? 'Sí' : 'No' }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-24">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="'Editar'"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(faq)"
                  />
                  <Button
                    v-tooltip.top="'Eliminar'"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[faq.id]"
                    @click="openDeletePopup(faq)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddFaq :on-close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditFaq
        v-if="showEditPopup"
        :faq="activeFaq"
        :on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      title="Eliminar FAQ"
      message="¿Estás seguro de que quieres eliminar"
      :message-value="deleteMessage"
      confirm-text="Eliminar"
      reject-text="Cancelar"
    />
  </SettingsLayout>
</template>
