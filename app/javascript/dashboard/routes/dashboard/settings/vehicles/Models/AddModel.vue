<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../../components/Modal.vue';

export default {
  name: 'AddVehicleModel',
  components: {
    NextButton,
    Modal,
  },
  props: {
    brandId: {
      type: [String, Number],
      required: true,
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      name: '',
      loading: false,
      show: true,
    };
  },
  validations: {
    name: { required },
  },
  methods: {
    async addModel() {
      this.loading = true;
      try {
        await this.$store.dispatch('vehicleModels/create', {
          vehicle_brand_id: this.brandId,
          name: this.name,
        });
        useAlert('Modelo creado correctamente');
        this.onClose();
      } catch (error) {
        useAlert(error?.message || 'Error al crear modelo');
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
        header-title="Nuevo Modelo"
        header-content="Agrega un modelo a esta marca"
      />
      <form class="flex flex-col w-full" @submit.prevent="addModel">
        <div class="w-full">
          <label :class="{ error: v$.name.$error }">
            Nombre del modelo *
            <input
              v-model="name"
              type="text"
              placeholder="Ej: MINI, ZNA, ARAUCA"
              @blur="v$.name.$touch"
            />
          </label>
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
            type="submit"
            label="Crear Modelo"
            :disabled="v$.name.$invalid || loading"
            :is-loading="loading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
