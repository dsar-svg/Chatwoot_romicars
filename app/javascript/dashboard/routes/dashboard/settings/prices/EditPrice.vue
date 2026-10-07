<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Modal from '../../../../components/Modal.vue';
import { PRICE_KINDS, kindOf } from './priceKinds';

export default {
  name: 'EditVehiclePrice',
  components: {
    NextButton,
    ComboBox,
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
      available: this.price.available !== false,
      details: this.price.details || '',
      ends_on: this.price.ends_on || null,
      loading: false,
      show: true,
    };
  },
  // A combo or promotion without a brand applies to every brand.
  validations() {
    return {
      description: { required },
      vehicle_brand_id: this.isPart ? { required } : {},
    };
  },
  computed: {
    kind() {
      return kindOf(this.price);
    },
    kindInfo() {
      return PRICE_KINDS[this.kind];
    },
    isPart() {
      return this.kind === 'repuesto';
    },
    brands() {
      return this.$store.getters['vehicleBrands/getBrands'];
    },
    filteredModels() {
      if (!this.vehicle_brand_id) return [];
      return this.$store.getters['vehicleModels/getModels'].filter(
        m => m.brand?.id === Number(this.vehicle_brand_id)
      );
    },
    brandOptions() {
      const options = this.brands.map(b => ({ value: b.id, label: b.name }));
      return this.isPart
        ? options
        : [{ value: null, label: 'Todas las marcas' }, ...options];
    },
    modelOptions() {
      return [
        { value: null, label: 'Sin modelo específico' },
        ...this.filteredModels.map(m => ({ value: m.id, label: m.name })),
      ];
    },
    latestRate() {
      return this.$store.getters['exchangeRates/getLatestRate'];
    },
    calculatedCostBs() {
      if (!this.divisa || !this.latestRate) return null;
      return Number((this.divisa * this.latestRate.equiv_13).toFixed(2));
    },
    calculatedBolivares() {
      if (this.calculatedCostBs === null) return null;
      return Math.round(this.calculatedCostBs / this.latestRate.rate);
    },
  },
  watch: {
    vehicle_brand_id() {
      this.vehicle_model_id = null;
    },
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
          details: this.details,
          ends_on: this.ends_on || null,
          active: this.active,
          available: this.available,
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
        :header-title="`Editar ${kindInfo.column.toLowerCase()}`"
        header-content="El bot lee los cambios al instante"
      />
      <form class="flex flex-col w-full" @submit.prevent="updatePrice">
        <div class="w-full">
          <label :class="{ error: v$.description.$error }">
            Descripción *
            <input
              v-model="description"
              type="text"
              :placeholder="kindInfo.placeholder"
              @blur="v$.description.$touch"
            />
          </label>
        </div>

        <div v-if="!isPart" class="w-full">
          <label>
            {{ kindInfo.detailsLabel }}
            <textarea
              v-model="details"
              rows="3"
              :placeholder="kindInfo.detailsPlaceholder"
            />
          </label>
        </div>

        <div v-if="kind === 'promocion'" class="w-full">
          <label>
            Válida hasta
            <input v-model="ends_on" type="date" />
          </label>
        </div>

        <div class="w-full mb-4">
          <label :class="{ error: v$.vehicle_brand_id.$error }">
            {{ isPart ? 'Marca *' : 'Marca' }}
          </label>
          <ComboBox
            v-model="vehicle_brand_id"
            :options="brandOptions"
            :has-error="v$.vehicle_brand_id.$error"
            :placeholder="isPart ? 'Seleccionar marca' : 'Todas las marcas'"
            search-placeholder="Buscar marca..."
            empty-state="Sin marcas"
            @update:model-value="v$.vehicle_brand_id.$touch()"
          />
        </div>

        <div class="w-full mb-4">
          <label>Modelo</label>
          <ComboBox
            v-model="vehicle_model_id"
            :options="modelOptions"
            :disabled="!vehicle_brand_id"
            placeholder="Sin modelo específico"
            search-placeholder="Buscar modelo..."
            empty-state="Sin modelos para esta marca"
          />
        </div>

        <div v-if="isPart" class="w-full">
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
              <input v-model.number="divisa" type="number" min="0" />
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
            id="price-active"
            v-model="active"
            type="checkbox"
            class="!w-auto"
          />
          <label for="price-active" class="!mb-0 !pb-0"> Activo </label>
          <input
            id="price-available"
            v-model="available"
            type="checkbox"
            class="!w-auto ltr:ml-4 rtl:mr-4"
          />
          <label for="price-available" class="!mb-0 !pb-0"> Disponible </label>
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
              v$.description.$invalid || v$.vehicle_brand_id.$invalid || loading
            "
            :is-loading="loading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
