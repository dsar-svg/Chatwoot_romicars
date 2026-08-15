<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  name: 'EditVehicleModel',
  components: {
    NextButton,
    Modal,
  },
  props: {
    model: {
      type: Object,
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
      name: this.model.name || '',
      active: this.model.active !== false,
      loading: false,
      show: true,
    };
  },
  validations: {
    name: { required },
  },
  methods: {
    async updateModel() {
      this.loading = true;
      try {
        await this.$store.dispatch('vehicleModels/update', {
          id: this.model.id,
          name: this.name,
          active: this.active,
        });
        useAlert('Modelo actualizado correctamente');
        this.onClose();
      } catch (error) {
        useAlert(error?.message || 'Error al actualizar modelo');
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
        header-title="Editar Modelo"
        header-content="Modifica el modelo de vehículo"
      />
      <form class="flex flex-col w-full" @submit.prevent="updateModel">
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

        <div class="flex items-center gap-2 pt-2 pb-4">
          <input
            v-model="active"
            type="checkbox"
            id="model-active"
            class="!w-auto"
          />
          <label for="model-active" class="!mb-0 !pb-0">
            Activo
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
            label="Guardar cambios"
            :disabled="v$.name.$invalid || loading"
            :is-loading="loading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
