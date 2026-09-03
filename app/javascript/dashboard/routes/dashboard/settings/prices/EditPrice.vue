<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  name: 'EditVehiclePrice',
  components: {
    NextButton,
    Modal,
  },
  props: {
    price: {
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
      description: this.price.description || '',
      variant: this.price.variant || '',
      synonyms: this.price.synonyms || '',
      cost_usd: this.price.cost_usd,
      divisa: this.price.divisa,
      monto_bs: this.price.monto_bs,
      bolivares: this.price.bolivares,
      vehicle_brand_id: this.price.brand?.id || null,
      vehicle_model_id: this.price.model?.id || null,
      active: this.price.active !== false,
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
    calculatedBolivares() {
      if (!this.divisa || !this.latestRate) return null;
      return Math.round(this.divisa * this.latestRate.equiv_13);
    },
    calculatedCostBs() {
      if (!this.divisa || !this.latestRate || this.calculatedBolivares === null) {
        return null;
      }
      const tasaBcv = this.latestRate.equiv_13 / 1.13;
      return Number((this.calculatedBolivares * tasaBcv).toFixed(2));
    },
  },
  watch: {
    divisa() {
      this.monto_bs = this.calculatedCostBs;
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
    async updatePrice() {
      this.loading = true;
      try {
        await this.$store.dispatch('vehiclePrices/update', {
          id: this.price.id,
          description: this.description,
          variant: this.variant,
          synonyms: this.synonyms,
          cost_usd: this.cost_usd,
          divisa: this.divisa,
          monto_bs: this.monto_bs,
          bolivares: this.bolivares,
          vehicle_brand_id: this.vehicle_brand_id,
          vehicle_model_id: this.vehicle_model_id || null,
          active: this.active,
        });
        useAlert('Precio actualizado correctamente');
        this.onClose();
      } catch (error) {
        useAlert(error?.message || 'Error al actualizar precio');
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
        header-title="Editar Precio"
        header-content="Modifica el precio del repuesto"
      />
      <form class="flex flex-col w-full" @submit.prevent="updatePrice">
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

        <div class="w-full">
          <label>
            Sinónimos
            <input
              v-model="synonyms"
              type="text"
              placeholder="Ej: amortiguador, shock absorber, suspensión"
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
              Divisa
              <input
                v-model.number="divisa"
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

        <div class="flex items-center gap-2 pt-2 pb-4">
          <input
            v-model="active"
            type="checkbox"
            id="price-active"
            class="!w-auto"
          />
          <label for="price-active" class="!mb-0 !pb-0">
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
