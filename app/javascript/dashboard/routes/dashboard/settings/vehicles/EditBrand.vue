<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  name: 'EditVehicleBrand',
  components: {
    NextButton,
    Modal,
  },
  props: {
    brand: {
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
      name: this.brand.name || '',
      active: this.brand.active !== false,
      loading: false,
      show: true,
    };
  },
  validations: {
    name: { required },
  },
  methods: {
    async updateBrand() {
      this.loading = true;
      try {
        await this.$store.dispatch('vehicleBrands/update', {
          id: this.brand.id,
          name: this.name,
          active: this.active,
        });
        useAlert('Marca actualizada correctamente');
        this.onClose();
      } catch (error) {
        useAlert(error?.message || 'Error al actualizar marca');
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
        header-title="Editar Marca"
        header-content="Modifica la marca de vehículos"
      />
      <form class="flex flex-col w-full" @submit.prevent="updateBrand">
        <div class="w-full">
          <label :class="{ error: v$.name.$error }">
            Nombre de la marca *
            <input
              v-model="name"
              type="text"
              placeholder="Ej: DONGFENG"
              @blur="v$.name.$touch"
            />
          </label>
        </div>

        <div class="flex items-center gap-2 pt-2 pb-4">
          <input
            id="brand-active"
            v-model="active"
            type="checkbox"
            class="!w-auto"
          />
          <label for="brand-active" class="!mb-0 !pb-0"> Activa </label>
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
