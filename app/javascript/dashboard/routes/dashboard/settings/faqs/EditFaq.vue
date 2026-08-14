<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

const CATEGORIES = [
  { value: 'repuestos', label: 'Repuestos' },
  { value: 'envios', label: 'Envíos' },
  { value: 'garantias', label: 'Garantías' },
  { value: 'pagos', label: 'Pagos' },
  { value: 'general', label: 'General' },
];

export default {
  name: 'EditFaq',
  components: {
    NextButton,
    Modal,
  },
  props: {
    faq: {
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
      question: this.faq.question || '',
      answer: this.faq.answer || '',
      category: this.faq.category || 'general',
      keywords: this.faq.keywords || '',
      priority: this.faq.priority || 0,
      active: this.faq.active !== false,
      categories: CATEGORIES,
      loading: false,
      show: true,
    };
  },
  validations: {
    question: { required },
    answer: { required },
  },
  methods: {
    async updateFaq() {
      this.loading = true;
      try {
        await this.$store.dispatch('faqs/update', {
          id: this.faq.id,
          question: this.question,
          answer: this.answer,
          category: this.category,
          keywords: this.keywords,
          priority: this.priority,
          active: this.active,
        });
        useAlert('FAQ actualizada correctamente');
        this.onClose();
      } catch (error) {
        useAlert(error?.message || 'Error al actualizar FAQ');
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
        header-title="Editar FAQ"
        header-content="Modifica la pregunta frecuente"
      />
      <form class="flex flex-col w-full" @submit.prevent="updateFaq">
        <div class="w-full">
          <label :class="{ error: v$.question.$error }">
            Pregunta *
            <input
              v-model="question"
              type="text"
              placeholder="¿Cuánto cuesta el envío?"
              @blur="v$.question.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.answer.$error }">
            Respuesta *
          </label>
          <textarea
            v-model="answer"
            rows="4"
            placeholder="El envío cuesta $5 USD en la ciudad..."
            class="w-full"
            :class="{ error: v$.answer.$error }"
            @blur="v$.answer.$touch"
          />
        </div>

        <div class="w-full">
          <label>
            Categoría
          </label>
          <select v-model="category" class="w-full">
            <option
              v-for="cat in categories"
              :key="cat.value"
              :value="cat.value"
            >
              {{ cat.label }}
            </option>
          </select>
        </div>

        <div class="w-full">
          <label>
            Palabras clave (separadas por coma)
          </label>
          <input
            v-model="keywords"
            type="text"
            placeholder="envío, delivery, costo envío"
          />
        </div>

        <div class="flex gap-4">
          <div class="w-full">
            <label>
              Prioridad (0-10)
            </label>
            <input
              v-model.number="priority"
              type="number"
              min="0"
              max="10"
            />
          </div>

          <div class="w-full flex items-center gap-2 pt-5">
            <input
              v-model="active"
              type="checkbox"
              id="faq-active-edit"
              class="!w-auto"
            />
            <label for="faq-active-edit" class="!mb-0 !pb-0">
              Activa
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
            label="Guardar cambios"
            :disabled="v$.answer.$invalid || v$.question.$invalid || loading"
            :is-loading="loading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
