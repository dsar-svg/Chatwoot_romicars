<script setup>
import { computed } from 'vue';
import { getLanguageName } from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import ContactDetailsItem from './ContactDetailsItem.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';

const props = defineProps({
  conversationAttributes: {
    type: Object,
    default: () => ({}),
  },
  contactAttributes: {
    type: Object,
    default: () => ({}),
  },
  conversation: {
    type: Object,
    default: () => ({}),
  },
});

const referer = computed(() => props.conversationAttributes.referer);
const initiatedAt = computed(
  () => props.conversationAttributes.initiated_at?.timestamp
);

const browserInfo = computed(() => props.conversationAttributes.browser);

const browserName = computed(() => {
  if (!browserInfo.value) return '';
  const { browser_name: name = '', browser_version: version = '' } =
    browserInfo.value;
  return `${name} ${version}`;
});

const browserLanguage = computed(() =>
  getLanguageName(props.conversationAttributes.browser_language)
);

const platformName = computed(() => {
  if (!browserInfo.value) return '';
  const { platform_name: name = '', platform_version: version = '' } =
    browserInfo.value;
  return `${name} ${version}`;
});

const createdAtIp = computed(() => props.contactAttributes.created_at_ip);

const hasResolution = computed(
  () =>
    props.conversation?.resolution_type === 'ganado' ||
    props.conversation?.resolution_type === 'perdido'
);

const resolutionTypeLabel = computed(() => {
  if (props.conversation?.resolution_type === 'ganado') return 'Ganado (Venta)';
  if (props.conversation?.resolution_type === 'perdido') return 'Perdido';
  return '';
});

const resolutionTypeClass = computed(() => {
  if (props.conversation?.resolution_type === 'ganado')
    return 'bg-n-green-3 text-n-green-11';
  if (props.conversation?.resolution_type === 'perdido')
    return 'bg-n-ruby-3 text-n-ruby-11';
  return '';
});

const resolutionReason = computed(
  () => props.conversation?.resolution_reason || ''
);

const resolutionNotes = computed(
  () => props.conversation?.resolution_notes || ''
);

const saleAmount = computed(() => props.conversation?.sale_amount || null);

const saleDate = computed(() => props.conversation?.sale_date || '');

const saleInvoice = computed(() => props.conversation?.sale_invoice || '');

const resolvedAt = computed(() => props.conversation?.resolved_at || '');

const staticElements = computed(() =>
  [
    {
      content: initiatedAt,
      title: 'CONTACT_PANEL.INITIATED_AT',
      key: 'static-initiated-at',
      type: 'static_attribute',
    },
    {
      content: browserLanguage,
      title: 'CONTACT_PANEL.BROWSER_LANGUAGE',
      key: 'static-browser-language',
      type: 'static_attribute',
    },
    {
      content: referer,
      title: 'CONTACT_PANEL.INITIATED_FROM',
      key: 'static-referer',
      type: 'static_attribute',
    },
    {
      content: browserName,
      title: 'CONTACT_PANEL.BROWSER',
      key: 'static-browser',
      type: 'static_attribute',
    },
    {
      content: platformName,
      title: 'CONTACT_PANEL.OS',
      key: 'static-platform',
      type: 'static_attribute',
    },
    {
      content: createdAtIp,
      title: 'CONTACT_PANEL.IP_ADDRESS',
      key: 'static-ip-address',
      type: 'static_attribute',
    },
  ].filter(attribute => !!attribute.content.value)
);
</script>

<template>
  <div class="conversation--details">
    <CustomAttributes
      :static-elements="staticElements"
      attribute-class="conversation--attribute"
      attribute-from="conversation_panel"
      attribute-type="conversation_attribute"
    >
      <template #staticItem="{ element }">
        <ContactDetailsItem
          :key="element.title"
          :title="$t(element.title)"
          :value="element.content.value"
        >
          <a
            v-if="element.key === 'static-referer'"
            :href="element.content.value"
            rel="noopener noreferrer nofollow"
            target="_blank"
            class="text-n-brand"
          >
            {{ element.content.value }}
          </a>
        </ContactDetailsItem>
      </template>
    </CustomAttributes>

    <div v-if="hasResolution" class="mt-3 px-4 pb-3">
      <h4 class="text-sm font-medium text-n-slate-12 mb-2">
        Resolución
      </h4>
      <div class="flex flex-col gap-2">
        <div class="flex items-center gap-2">
          <span class="text-xs text-n-slate-10 w-20">Resultado</span>
          <span
            class="text-xs font-medium px-2 py-0.5 rounded-full"
            :class="resolutionTypeClass"
          >
            {{ resolutionTypeLabel }}
          </span>
        </div>
        <div v-if="resolutionReason" class="flex items-center gap-2">
          <span class="text-xs text-n-slate-10 w-20">Motivo</span>
          <span class="text-xs text-n-slate-12">{{ resolutionReason }}</span>
        </div>
        <div v-if="saleAmount" class="flex items-center gap-2">
          <span class="text-xs text-n-slate-10 w-20">Monto</span>
          <span class="text-xs text-n-slate-12">${{ saleAmount }}</span>
        </div>
        <div v-if="saleDate" class="flex items-center gap-2">
          <span class="text-xs text-n-slate-10 w-20">Fecha</span>
          <span class="text-xs text-n-slate-12">{{ saleDate }}</span>
        </div>
        <div v-if="saleInvoice" class="flex items-center gap-2">
          <span class="text-xs text-n-slate-10 w-20">Factura</span>
          <span class="text-xs text-n-slate-12">{{ saleInvoice }}</span>
        </div>
        <div v-if="resolutionNotes" class="flex items-start gap-2">
          <span class="text-xs text-n-slate-10 w-20">Notas</span>
          <span class="text-xs text-n-slate-12">{{ resolutionNotes }}</span>
        </div>
        <div v-if="resolvedAt" class="flex items-center gap-2">
          <span class="text-xs text-n-slate-10 w-20">Cerrado</span>
          <span class="text-xs text-n-slate-12">{{ resolvedAt }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
