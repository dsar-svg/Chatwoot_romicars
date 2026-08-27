<script setup>
import { ref, computed, watch } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'resolve']);

const resolutionType = ref('');
const resolutionReason = ref('');
const resolutionNotes = ref('');
const requestedProduct = ref('');
const saleAmount = ref(null);
const saleDate = ref('');
const saleInvoice = ref('');

const outcomes = [
  {
    value: 'ganado',
    label: 'Cierre Ganado (Venta)',
    activeClass: 'border-n-green-9 bg-n-green-3 text-n-green-12',
    dotClass: 'border-n-green-9',
    fillClass: 'bg-n-green-9',
  },
  {
    value: 'perdido',
    label: 'Cierre Perdido',
    activeClass: 'border-n-ruby-9 bg-n-ruby-3 text-n-ruby-12',
    dotClass: 'border-n-ruby-9',
    fillClass: 'bg-n-ruby-9',
  },
  {
    value: 'consulta',
    label: 'Consulta Resuelta',
    activeClass: 'border-n-blue-9 bg-n-blue-3 text-n-blue-12',
    dotClass: 'border-n-blue-9',
    fillClass: 'bg-n-blue-9',
  },
];

// Must stay in sync with Conversation::RESOLUTION_REASONS.
const reasons = [
  { value: 'sin_stock', label: 'Producto sin stock' },
  { value: 'precio', label: 'Precio' },
  { value: 'sin_respuesta', label: 'Sin respuesta' },
  { value: 'otro', label: 'Otro' },
];

const isWon = computed(() => resolutionType.value === 'ganado');
const isLost = computed(() => resolutionType.value === 'perdido');
const needsRequestedProduct = computed(
  () => isLost.value && resolutionReason.value === 'sin_stock'
);

const hasSaleAmount = computed(
  () => saleAmount.value !== null && saleAmount.value !== ''
);

const canSubmit = computed(() => {
  if (!resolutionType.value) return false;
  if (isWon.value && !hasSaleAmount.value) return false;
  if (isLost.value && !resolutionReason.value) return false;
  if (needsRequestedProduct.value && !requestedProduct.value.trim()) return false;
  return true;
});

const resetForm = () => {
  resolutionType.value = '';
  resolutionReason.value = '';
  resolutionNotes.value = '';
  requestedProduct.value = '';
  saleAmount.value = null;
  saleDate.value = '';
  saleInvoice.value = '';
};

const handleClose = () => {
  resetForm();
  emit('close');
};

// Modal owns `show` through defineModel, so it writes back on backdrop click and on the
// close button. Binding a readonly computed here made those writes fail silently.
const show = computed({
  get: () => props.show,
  set: value => {
    if (!value) handleClose();
  },
});

// Selecting a different outcome must drop the fields that no longer apply, otherwise a
// stale sale amount or reason rides along with the submit.
watch(resolutionType, () => {
  resolutionReason.value = '';
  requestedProduct.value = '';
  saleAmount.value = null;
  saleDate.value = '';
  saleInvoice.value = '';
});

watch(resolutionReason, () => {
  if (!needsRequestedProduct.value) requestedProduct.value = '';
});

const handleSubmit = () => {
  if (!canSubmit.value) return;

  emit('resolve', {
    resolutionType: resolutionType.value,
    resolutionReason: isLost.value ? resolutionReason.value : null,
    resolutionNotes: resolutionNotes.value,
    requestedProduct: needsRequestedProduct.value
      ? requestedProduct.value.trim()
      : null,
    saleAmount: isWon.value ? saleAmount.value : null,
    saleDate: isWon.value && saleDate.value ? saleDate.value : null,
    saleInvoice: isWon.value ? saleInvoice.value : null,
  });
  resetForm();
};
</script>

<template>
  <!-- `on-close` is deprecated in Modal; the v-model setter above handles every close path. -->
  <Modal v-model:show="show">
    <template #header>
      <woot-modal-header
        header-title="Cerrar Conversación"
        header-content="Selecciona el resultado de esta conversación"
      />
    </template>
    <form class="flex flex-col w-full p-4 gap-4" @submit.prevent="handleSubmit">
      <!-- Resultado -->
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-3">
          Resultado *
        </label>
        <div class="grid grid-cols-3 gap-3">
          <button
            v-for="outcome in outcomes"
            :key="outcome.value"
            type="button"
            class="flex items-center gap-2 p-4 rounded-lg border-2 transition-colors text-left"
            :class="
              resolutionType === outcome.value
                ? outcome.activeClass
                : 'border-n-slate-6 hover:border-n-slate-8 bg-transparent text-n-slate-11'
            "
            @click="resolutionType = outcome.value"
          >
            <div
              class="w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0"
              :class="
                resolutionType === outcome.value
                  ? outcome.dotClass
                  : 'border-n-slate-8'
              "
            >
              <div
                v-if="resolutionType === outcome.value"
                class="w-2 h-2 rounded-full"
                :class="outcome.fillClass"
              />
            </div>
            <span class="text-sm font-medium">{{ outcome.label }}</span>
          </button>
        </div>
      </div>

      <!-- Campos de venta (solo ganado) -->
      <div v-if="isWon" class="p-4 rounded-lg bg-n-alpha-1 space-y-4">
        <label class="block text-sm font-medium text-n-slate-12">
          Datos de la venta
        </label>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-medium text-n-slate-11 mb-1">
              Monto de venta (USD) *
            </label>
            <input
              v-model.number="saleAmount"
              type="number"
              step="0.01"
              min="0"
              placeholder="0.00"
              class="w-full px-3 py-2 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand-8"
            />
          </div>
          <div>
            <label class="block text-xs font-medium text-n-slate-11 mb-1">
              Fecha de venta
            </label>
            <input
              v-model="saleDate"
              type="date"
              class="w-full px-3 py-2 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand-8"
            />
          </div>
        </div>
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            N° de factura
          </label>
          <input
            v-model="saleInvoice"
            type="text"
            placeholder="FAC-0001"
            class="w-full px-3 py-2 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand-8"
          />
        </div>
      </div>

      <!-- Motivos (solo perdido) -->
      <div v-if="isLost">
        <label class="block text-sm font-medium text-n-slate-12 mb-3">
          Motivo *
        </label>
        <div class="grid grid-cols-2 gap-2">
          <button
            v-for="reason in reasons"
            :key="reason.value"
            type="button"
            class="flex items-center gap-2 p-3 rounded-lg border-2 text-left transition-colors"
            :class="
              resolutionReason === reason.value
                ? 'border-n-brand-9 bg-n-brand-3 text-n-slate-12'
                : 'border-n-slate-6 hover:border-n-slate-8 bg-transparent text-n-slate-11'
            "
            @click="resolutionReason = reason.value"
          >
            <div
              class="w-3.5 h-3.5 rounded-full border-2 flex items-center justify-center flex-shrink-0"
              :class="
                resolutionReason === reason.value
                  ? 'border-n-brand-9'
                  : 'border-n-slate-8'
              "
            >
              <div
                v-if="resolutionReason === reason.value"
                class="w-1.5 h-1.5 rounded-full bg-n-brand-9"
              />
            </div>
            <span class="text-sm">{{ reason.label }}</span>
          </button>
        </div>
      </div>

      <!-- Repuesto solicitado (solo perdido por falta de stock) -->
      <div v-if="needsRequestedProduct" class="p-4 rounded-lg bg-n-alpha-1">
        <label class="block text-xs font-medium text-n-slate-11 mb-1">
          Repuesto solicitado *
        </label>
        <input
          v-model="requestedProduct"
          type="text"
          placeholder="Ej: Bomba de agua Chery Arauca"
          class="w-full px-3 py-2 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand-8"
        />
        <p class="text-[11px] text-n-slate-9 mt-1">
          Alimenta el reporte de repuestos solicitados que no tenemos en stock.
        </p>
      </div>

      <!-- Observaciones -->
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          Observaciones
        </label>
        <textarea
          v-model="resolutionNotes"
          rows="3"
          placeholder="Detalles adicionales sobre el cierre..."
          class="w-full px-3 py-2 rounded-lg border border-n-slate-6 bg-transparent text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand-8 resize-none"
        />
      </div>

      <!-- Botones -->
      <div class="flex flex-row justify-end w-full gap-2 pt-2">
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
  </Modal>
</template>
