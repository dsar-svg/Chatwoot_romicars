<script>
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  name: 'ImportVehiclePrices',
  components: {
    NextButton,
    Modal,
  },
  props: {
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  data() {
    return {
      file: null,
      loading: false,
      show: true,
      result: null,
    };
  },
  methods: {
    onFileChange(event) {
      this.file = event.target.files[0];
      this.result = null;
    },
    async importPrices() {
      if (!this.file) return;

      this.loading = true;
      try {
        const formData = new FormData();
        formData.append('file', this.file);
        this.result = await this.$store.dispatch('vehiclePrices/import', formData);
        if (this.result.success) {
          useAlert(
            `Importación completada: ${this.result.created} creados, ${this.result.updated} actualizados`
          );
          await this.$store.dispatch('vehiclePrices/get');
        } else {
          useAlert(this.result.error || 'Error al importar');
        }
      } catch (error) {
        useAlert(error?.message || 'Error al importar precios');
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        header-title="Importar Precios"
        header-content="Importa precios desde un archivo CSV o Excel"
      />

      <div class="flex flex-col w-full p-4">
        <div class="mb-4">
          <p class="text-sm text-n-slate-11 mb-2">
            Formato esperado del CSV:
          </p>
          <code class="text-xs text-n-slate-11 bg-n-alpha-2 px-2 py-1 rounded">
            DESCRIPCION,MODELO,COSTO,DIVISA,MONTO Bs,BOLIVARES
          </code>
        </div>

        <div class="mb-4">
          <label>
            Seleccionar archivo (CSV o Excel)
            <input
              type="file"
              accept=".csv,.xlsx,.xls"
              @change="onFileChange"
            />
          </label>
        </div>

        <div v-if="result && result.success" class="mb-4 p-3 rounded-lg bg-n-green-2 text-n-green-12 text-sm">
          <p>✅ Importación exitosa</p>
          <p>Creados: {{ result.created }} | Actualizados: {{ result.updated }}</p>
          <p v-if="result.errors?.length">
            Errores: {{ result.errors.length }} filas con problemas
          </p>
        </div>

        <div v-if="result && !result.success" class="mb-4 p-3 rounded-lg bg-n-ruby-2 text-n-ruby-12 text-sm">
          <p>❌ {{ result.error }}</p>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            label="Cancelar"
            @click.prevent="onClose"
          />
          <NextButton
            label="Importar"
            :disabled="!file || loading"
            :is-loading="loading"
            @click="importPrices"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>
