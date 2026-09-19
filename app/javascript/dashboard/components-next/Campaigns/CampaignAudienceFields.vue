<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import LocationStateAPI from 'dashboard/api/locationStates';
import LocationCityAPI from 'dashboard/api/locationCities';

import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const props = defineProps({
  // { labels: [id], brands: [id], models: [id], states: [id], cities: [id] }
  modelValue: {
    type: Object,
    required: true,
  },
  hasError: {
    type: Boolean,
    default: false,
  },
  message: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const store = useStore();

const labels = useMapGetter('labels/getLabels');
const brands = useMapGetter('vehicleBrands/getBrands');
const vehicleModels = useMapGetter('vehicleModels/getModels');
const states = ref([]);
const cities = ref([]);

const update = (key, value) =>
  emit('update:modelValue', { ...props.modelValue, [key]: value });

const activeOnly = items => items?.filter(item => item.active !== false) ?? [];

const toOptions = items =>
  items.map(({ id, name }) => ({ value: id, label: name }));

const labelOptions = computed(
  () => labels.value?.map(({ id, title }) => ({ value: id, label: title })) ?? []
);

const brandOptions = computed(() => toOptions(activeOnly(brands.value)));

const stateOptions = computed(() => toOptions(states.value));

// A child list narrows to its selected parents; with no parent picked everything is
// offered. The parent always prefixes the label because two parents can share a child
// name — "Miranda Valencia" is not "Carabobo Valencia".
const narrowTo = (items, selectedParents, parentOf) =>
  selectedParents.length
    ? items.filter(item => selectedParents.includes(parentOf(item)?.id))
    : items;

const modelOptions = computed(() =>
  narrowTo(
    activeOnly(vehicleModels.value),
    props.modelValue.brands,
    model => model.brand
  ).map(model => ({
    value: model.id,
    label: [model.brand?.name, model.name].filter(Boolean).join(' '),
  }))
);

const cityOptions = computed(() =>
  narrowTo(cities.value, props.modelValue.states, city => city.state).map(
    city => ({
      value: city.id,
      label: props.modelValue.states.length
        ? city.name
        : [city.name, city.state?.name].filter(Boolean).join(', '),
    })
  )
);

// Dropping a parent would otherwise leave its children selected but no longer listed.
const pruneTo = (key, options) => {
  const listed = options.map(({ value }) => value);
  const kept = props.modelValue[key].filter(id => listed.includes(id));
  if (kept.length !== props.modelValue[key].length) update(key, kept);
};

watch(
  () => props.modelValue.brands,
  () => pruneTo('models', modelOptions.value)
);

watch(
  () => props.modelValue.states,
  () => pruneTo('cities', cityOptions.value)
);

onMounted(async () => {
  store.dispatch('vehicleBrands/get');
  // No parent id on either call: each catalogue is loaded once and narrowed client side.
  store.dispatch('vehicleModels/get');

  try {
    const [stateResponse, cityResponse] = await Promise.all([
      LocationStateAPI.get(),
      LocationCityAPI.get(),
    ]);
    states.value = stateResponse.data?.payload ?? [];
    cities.value = cityResponse.data?.payload ?? [];
  } catch {
    // A failed lookup only costs the location pickers their options.
    states.value = [];
    cities.value = [];
  }
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-col gap-1">
      <label
        for="audience-labels"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ t('CAMPAIGN.AUDIENCE_FIELDS.LABELS.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        id="audience-labels"
        :model-value="modelValue.labels"
        :options="labelOptions"
        :placeholder="t('CAMPAIGN.AUDIENCE_FIELDS.LABELS.PLACEHOLDER')"
        :has-error="hasError"
        class="[&>div>button]:bg-n-alpha-black2"
        @update:model-value="value => update('labels', value)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label
        for="audience-brands"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ t('CAMPAIGN.AUDIENCE_FIELDS.BRANDS.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        id="audience-brands"
        :model-value="modelValue.brands"
        :options="brandOptions"
        :placeholder="t('CAMPAIGN.AUDIENCE_FIELDS.BRANDS.PLACEHOLDER')"
        :empty-state="t('CAMPAIGN.AUDIENCE_FIELDS.BRANDS.EMPTY')"
        :has-error="hasError"
        class="[&>div>button]:bg-n-alpha-black2"
        @update:model-value="value => update('brands', value)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label
        for="audience-models"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ t('CAMPAIGN.AUDIENCE_FIELDS.MODELS.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        id="audience-models"
        :model-value="modelValue.models"
        :options="modelOptions"
        :placeholder="t('CAMPAIGN.AUDIENCE_FIELDS.MODELS.PLACEHOLDER')"
        :empty-state="t('CAMPAIGN.AUDIENCE_FIELDS.MODELS.EMPTY')"
        :has-error="hasError"
        class="[&>div>button]:bg-n-alpha-black2"
        @update:model-value="value => update('models', value)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label
        for="audience-states"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ t('CAMPAIGN.AUDIENCE_FIELDS.STATES.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        id="audience-states"
        :model-value="modelValue.states"
        :options="stateOptions"
        :placeholder="t('CAMPAIGN.AUDIENCE_FIELDS.STATES.PLACEHOLDER')"
        :empty-state="t('CAMPAIGN.AUDIENCE_FIELDS.STATES.EMPTY')"
        :has-error="hasError"
        class="[&>div>button]:bg-n-alpha-black2"
        @update:model-value="value => update('states', value)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label
        for="audience-cities"
        class="mb-0.5 text-sm font-medium text-n-slate-12"
      >
        {{ t('CAMPAIGN.AUDIENCE_FIELDS.CITIES.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        id="audience-cities"
        :model-value="modelValue.cities"
        :options="cityOptions"
        :placeholder="t('CAMPAIGN.AUDIENCE_FIELDS.CITIES.PLACEHOLDER')"
        :empty-state="t('CAMPAIGN.AUDIENCE_FIELDS.CITIES.EMPTY')"
        :has-error="hasError"
        class="[&>div>button]:bg-n-alpha-black2"
        @update:model-value="value => update('cities', value)"
      />
    </div>

    <p
      v-if="message"
      class="-mt-2 text-sm"
      :class="hasError ? 'text-n-ruby-9' : 'text-n-slate-11'"
    >
      {{ message }}
    </p>
  </div>
</template>
