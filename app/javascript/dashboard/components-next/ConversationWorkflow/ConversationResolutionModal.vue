<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';

const { t } = useI18n();

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'resolve']);

const resolutionType = ref('');
const resolutionReason = ref('');
const resolutionNotes = ref('');
const saleAmount = ref(null);
const saleDate = ref('');
const saleInvoice = ref('');
const show = computed(() => props.show);

const reasons = [
  { value: 'sin_stock', label: 'Producto sin stock' },
  { value: 'precio', label: 'Precio' },
  { value: 'sin_respuesta', label: 'Sin respuesta' },
  { value: 'otro', label: 'Otro' },
];

const canSubmit = computed(() => {
  if (!resolutionType.value) return false;
  if (resolutionType.value === 'perdido' && !resolutionReason.value) return false;
  if (resolutionType.value === 'ganado' && !saleAmount.value) return false;
  return true;
});

const handleSubmit = () => {
  emit('resolve', {
    resolutionType: resolutionType.value,
    resolutionReason:
      resolutionType.value === 'perdido' ? resolutionReason.value : 'venta',
    resolutionNotes: resolutionNotes.value,
    saleAmount:
      resolutionType.value === 'ganado' ? saleAmount.value : null,
    saleDate:
      resolutionType.value === 'ganado' && saleDate.value ? saleDate.value : null,
    saleInvoice:
      resolutionType.value === 'ganado' ? saleInvoice.value : null,
  });
  resetForm();
};

const resetForm = () => {
  resolutionType.value = '';
  resolutionReason.value = '';
  resolutionNotes.value = '';
  saleAmount.value = null;
  saleDate.value = '';
  saleInvoice.value = '';
};

const handleClose = () => {
  resetForm();
  emit('close');
};
</script>

<template>
  <Modal v-model:show="show" :on-close="handleClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        header-title="Cerrar Conversación"
        header-content="Selecciona el resultado de esta conversación"
      />
      <form class="flex flex-col w-full p-4" @submit.prevent="handleSubmit">
        <div class="mb-4">
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            Resultado *
          </label>
          <div class="flex gap-4">
            <label
              class="flex items-center gap-2 cursor-pointer p-3 rounded-lg border"
              :class="
                resolutionType === 'ganado'
                  ? 'border-n-green-11 bg-n-green-2'
                  : 'border-n-slate-4 bg-white'
              "
            >
              <input
                v-model="resolutionType"
                type="radio"
                value="ganado"
                class="!w-auto"
              />
              <span class="text-sm font-medium text-n-green-11">
                Cierre Ganado (Venta)
              </span>
            </label>
            <label
              class="flex items-center gap-2 cursor-pointer p-3 rounded-lg border"
              :class="
                resolutionType === 'perdido'
                  ? 'border-n-ruby-11 bg-n-ruby-2'
                  : 'border-n-slate-4 bg-white'
              "
            >
              <input
                v-model="resolutionType"
                type="radio"
                value="perdido"
                class="!w-auto"
              />
              <span class="text-sm font-medium text-n-ruby-11">
                Cierre Perdido
              </span>
            </label>
          </div>
        </div>

        <div v-if="resolutionType === 'ganado'" class="mb-4">
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            Datos de la venta
          </label>
          <div class="flex gap-4 mb-3">
            <div class="w-full">
              <label class="block text-xs text-n-slate-11 mb-1">
                Monto de venta (USD) *
              </label>
              <input
                v-model.number="saleAmount"
                type="number"
                step="0.01"
                min="0"
                placeholder="0.00"
                class="w-full rounded-lg border border-n-slate-4 p-2.5 text-sm focus:outline-n-brand focus:ring-1 focus:ring-n-brand"
              />
            </div>
            <div class="w-full">
              <label class="block text-xs text-n-slate-11 mb-1">
                Fecha de venta
              </label>
              <input
                v-model="saleDate"
                type="date"
                class="w-full rounded-lg border border-n-slate-4 p-2.5 text-sm focus:outline-n-brand focus:ring-1 focus:ring-n-brand"
              />
            </div>
          </div>
          <div>
            <label class="block text-xs text-n-slate-11 mb-1">
              N° de factura
            </label>
            <input
              v-model="saleInvoice"
              type="text"
              placeholder="FAC-0001"
              class="w-full rounded-lg border border-n-slate-4 p-2.5 text-sm focus:outline-n-brand focus:ring-1 focus:ring-n-brand"
            />
          </div>
        </div>

        <div v-if="resolutionType === 'perdido'" class="mb-4">
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            Motivo *
          </label>
          <div class="flex flex-col gap-2">
            <label
              v-for="reason in reasons"
              :key="reason.value"
              class="flex items-center gap-2 cursor-pointer p-2 rounded-lg border"
              :class="
                resolutionReason === reason.value
                  ? 'border-n-brand-11 bg-n-brand-2'
                  : 'border-n-slate-4 bg-white'
              "
            >
              <input
                v-model="resolutionReason"
                type="radio"
                :value="reason.value"
                class="!w-auto"
              />
              <span class="text-sm text-n-slate-12">{{ reason.label }}</span>
            </label>
          </div>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-n-slate-12 mb-1">
            Observaciones
          </label>
          <textarea
            v-model="resolutionNotes"
            rows="3"
            placeholder="Detalles adicionales sobre el cierre..."
            class="w-full rounded-lg border border-n-slate-4 p-2.5 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-n-brand focus:ring-1 focus:ring-n-brand"
          />
        </div>

        <div class="flex flex-row justify-end w-full gap-2">
          <NextButton
            faded
            slate
            type="button"
            label="Cancelar"
            @click="handleClose"
          />
          <NextButton
            type="submit"
            label="Cerrar Conversación"
            :disabled="!canSubmit"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
