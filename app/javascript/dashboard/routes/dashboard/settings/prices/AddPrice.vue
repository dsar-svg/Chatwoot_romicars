<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  name: 'AddVehiclePrice',
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
      description: '',
      variant: '',
      cost_usd: null,
      divisor: null,
      cost_bs: null,
      bolivares: null,
      vehicle_brand_id: null,
      vehicle_model_id: null,
      loading: false,
      show: true,
    };
  },
  validations: {
    description: { required },
    vehicle_brand_id: { required },
  },
  computed: {
    brands() {
      return this.$store.getters['vehicleBrands/getBrands'];
    },
    filteredModels() {
      if (!this.vehicle_brand_id) return [];
      return this.$store.getters['vehicleModels/getModels'].filter(
        m => m.brand?.id === Number(this.vehicle_brand_id)
      );
    },
    latestRate() {
      return this.$store.getters['exchangeRates/getLatestRate'];
    },
    calculatedCostBs() {
      if (!this.divisor || !this.latestRate) return null;
      return Number((this.divisor * this.latestRate.equiv_13).toFixed(2));
    },
    calculatedBolivares() {
      if (!this.divisor) return null;
      return Number((this.divisor * 1.13).toFixed(2));
    },
  },
  watch: {
    divisor() {
      this.cost_bs = this.calculatedCostBs;
      this.bolivares = this.calculatedBolivares;
    },
  },
  async mounted() {
    await Promise.all([
      this.$store.dispatch('vehicleBrands/get'),
      this.$store.dispatch('vehicleModels/get'),
      this.$store.dispatch('exchangeRates/get'),
    ]);
  },
  methods: {
    async addPrice() {
      this.loading = true;
      try {
        await this.$store.dispatch('vehiclePrices/create', {
          description: this.description,
          variant: this.variant,
          cost_usd: this.cost_usd,
          divisor: this.divisor,
          cost_bs: this.cost_bs,
          bolivares: this.bolivares,
          vehicle_brand_id: this.vehicle_brand_id,
          vehicle_model_id: this.vehicle_model_id || null,
        });
        useAlert('Precio creado correctamente');
        this.onClose();
      } catch (error) {
        useAlert(error?.message || 'Error al crear precio');
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
        header-title="Nuevo Precio"
        header-content="Agrega un precio de repuesto"
      />
      <form class="flex flex-col w-full" @submit.prevent="addPrice">
        <div class="w-full">
          <label :class="{ error: v$.description.$error }">
            Descripción *
            <input
              v-model="description"
              type="text"
              placeholder="Ej: AMORTIGUADOR TRASERO"
              @blur="v$.description.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.vehicle_brand_id.$error }">
            Marca *
            <select
              v-model="vehicle_brand_id"
              class="w-full"
              @blur="v$.vehicle_brand_id.$touch"
            >
              <option :value="null">Seleccionar marca</option>
              <option
                v-for="brand in brands"
                :key="brand.id"
                :value="brand.id"
              >
                {{ brand.name }}
              </option>
            </select>
          </label>
        </div>

        <div class="w-full">
          <label>
            Modelo
            <select v-model="vehicle_model_id" class="w-full">
              <option :value="null">Sin modelo específico</option>
              <option
                v-for="model in filteredModels"
                :key="model.id"
                :value="model.id"
              >
                {{ model.name }}
              </option>
            </select>
          </label>
        </div>

        <div class="w-full">
          <label>
            Variante
            <input
              v-model="variant"
              type="text"
              placeholder="Ej: BUS/VAN/TRUCK, 4X2, 4X4"
            />
          </label>
        </div>

        <div class="flex gap-4">
          <div class="w-full">
            <label>
              Costo USD
              <input
                v-model.number="cost_usd"
                type="number"
                step="0.01"
                min="0"
              />
            </label>
          </div>
          <div class="w-full">
            <label>
              Divisor (DIVISA)
              <input
                v-model.number="divisor"
                type="number"
                min="0"
              />
            </label>
          </div>
        </div>

        <div class="flex gap-4">
          <div class="w-full">
            <label>
              Monto Bs. (auto)
              <input
                :value="calculatedCostBs"
                type="text"
                disabled
                class="!bg-n-alpha-2"
              />
            </label>
          </div>
          <div class="w-full">
            <label>
              Bolívares (auto)
              <input
                :value="calculatedBolivares"
                type="text"
                disabled
                class="!bg-n-alpha-2"
              />
            </label>
          </div>
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
            label="Crear Precio"
            :disabled="
              v$.description.$invalid ||
              v$.vehicle_brand_id.$invalid ||
              loading
            "
            :is-loading="loading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
