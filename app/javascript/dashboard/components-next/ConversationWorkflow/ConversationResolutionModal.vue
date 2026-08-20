<script setup>
import { ref, computed } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';

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
    saleAmount: resolutionType.value === 'ganado' ? saleAmount.value : null,
    saleDate:
      resolutionType.value === 'ganado' && saleDate.value ? saleDate.value : null,
    saleInvoice: resolutionType.value === 'ganado' ? saleInvoice.value : null,
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
        <div class="grid grid-cols-2 gap-3">
          <button
            type="button"
            class="flex items-center gap-2 p-4 rounded-lg border-2 transition-colors"
            :class="
              resolutionType === 'ganado'
                ? 'border-n-green-9 bg-n-green-3 text-n-green-12'
                : 'border-n-slate-6 hover:border-n-slate-8 bg-transparent text-n-slate-11'
            "
            @click="resolutionType = 'ganado'"
          >
            <div
              class="w-4 h-4 rounded-full border-2 flex items-center justify-center"
              :class="
                resolutionType === 'ganado'
                  ? 'border-n-green-9'
                  : 'border-n-slate-8'
              "
            >
              <div
                v-if="resolutionType === 'ganado'"
                class="w-2 h-2 rounded-full bg-n-green-9"
              />
            </div>
            <span class="text-sm font-medium">Cierre Ganado (Venta)</span>
          </button>

          <button
            type="button"
            class="flex items-center gap-2 p-4 rounded-lg border-2 transition-colors"
            :class="
              resolutionType === 'perdido'
                ? 'border-n-ruby-9 bg-n-ruby-3 text-n-ruby-12'
                : 'border-n-slate-6 hover:border-n-slate-8 bg-transparent text-n-slate-11'
            "
            @click="resolutionType = 'perdido'"
          >
            <div
              class="w-4 h-4 rounded-full border-2 flex items-center justify-center"
              :class="
                resolutionType === 'perdido'
                  ? 'border-n-ruby-9'
                  : 'border-n-slate-8'
              "
            >
              <div
                v-if="resolutionType === 'perdido'"
                class="w-2 h-2 rounded-full bg-n-ruby-9"
              />
            </div>
            <span class="text-sm font-medium">Cierre Perdido</span>
          </button>
        </div>
      </div>

      <!-- Campos de venta (solo ganado) -->
      <div v-if="resolutionType === 'ganado'" class="p-4 rounded-lg bg-n-alpha-1 space-y-4">
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
      <div v-if="resolutionType === 'perdido'">
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
              class="w-3.5 h-3.5 rounded-full border-2 flex items-center justify-center"
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
