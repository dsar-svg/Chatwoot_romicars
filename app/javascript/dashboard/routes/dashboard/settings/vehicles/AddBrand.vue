<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  name: 'AddVehicleBrand',
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
    async addBrand() {
      this.loading = true;
      try {
        await this.$store.dispatch('vehicleBrands/create', {
          name: this.name,
        });
        useAlert('Marca creada correctamente');
        this.onClose();
      } catch (error) {
        useAlert(error?.message || 'Error al crear marca');
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
        header-title="Nueva Marca"
        header-content="Agrega una marca de vehículos"
      />
      <form class="flex flex-col w-full" @submit.prevent="addBrand">
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
            label="Crear Marca"
            :disabled="v$.name.$invalid || loading"
            :is-loading="loading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
