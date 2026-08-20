<script setup>
import { computed } from 'vue';

const props = defineProps({
  demand: {
    type: Object,
    default: () => ({ popular_products: [], channel_breakdown: [], total_30d: 0 }),
  },
  loading: { type: Boolean, default: false },
});

const channelIcon = {
  webwidget: 'i-lucide-globe',
  twitterprofile: 'i-lucide-twitter',
  whatsapp: 'i-lucide-message-circle',
  email: 'i-lucide-mail',
  facebookpage: 'i-lucide-facebook',
  instagram: 'i-lucide-instagram',
  telegram: 'i-lucide-send',
  sms: 'i-lucide-smartphone',
  tiktok: 'i-lucide-music',
};

const products = computed(() =>
  (props.demand.popular_products || []).slice(0, 8)
);

const channels = computed(() =>
  (props.demand.channel_breakdown || []).sort((a, b) => b.count - a.count)
);

const maxCount = computed(() =>
  Math.max(
    channels.value.reduce((m, c) => Math.max(m, c.count), 1),
    products.value.reduce((m, p) => Math.max(m, p.count), 1)
  )
);

function barWidth(count) {
  return `${(count / maxCount.value) * 100}%`;
}

function iconForChannel(ch) {
  return channelIcon[ch] || 'i-lucide-message-square';
}
</script>

<template>
  <div class="bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5">
    <div class="flex items-center gap-2 mb-5">
      <span class="i-lucide-bar-chart-2 size-4 text-[#1A365D] dark:text-blue-11" />
      <h2 class="text-sm font-semibold text-n-slate-12">Demanda e Interés</h2>
    </div>

    <div v-if="loading" class="space-y-3 animate-pulse">
      <div v-for="i in 4" :key="i" class="h-4 bg-n-alpha-2 rounded w-full" />
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <!-- Popular products -->
      <div>
        <p class="text-[10px] font-semibold uppercase tracking-widest text-n-slate-9 mb-3">
          Productos más solicitados
        </p>
        <div v-if="products.length" class="space-y-2">
          <div v-for="product in products" :key="product.name" class="flex items-center gap-2">
            <span class="size-3.5 text-n-slate-10 flex-shrink-0 i-lucide-car" />
            <span class="text-xs text-n-slate-11 w-28 truncate flex-shrink-0">
              {{ product.name }}
            </span>
            <div class="flex-1 bg-n-alpha-2 rounded-full h-1.5 overflow-hidden">
              <div
                class="h-full rounded-full bg-[#1A365D] dark:bg-blue-11 transition-all duration-500"
                :style="{ width: barWidth(product.count) }"
              />
            </div>
            <span class="text-xs font-medium text-n-slate-12 tabular-nums w-8 text-right flex-shrink-0">
              {{ product.count }}
            </span>
          </div>
        </div>
        <p v-else class="text-xs text-n-slate-9">Sin datos de productos aún.</p>
      </div>

      <!-- Channels breakdown -->
      <div>
        <p class="text-[10px] font-semibold uppercase tracking-widest text-n-slate-9 mb-3">
          Por canal (30 días)
        </p>
        <div v-if="channels.length" class="space-y-2.5">
          <div v-for="ch in channels" :key="ch.channel" class="flex items-center gap-2">
            <span class="size-3.5 text-n-slate-10 flex-shrink-0" :class="iconForChannel(ch.channel)" />
            <span class="text-xs text-n-slate-11 w-28 truncate capitalize flex-shrink-0">
              {{ ch.channel }}
            </span>
            <div class="flex-1 bg-n-alpha-2 rounded-full h-1.5 overflow-hidden">
              <div
                class="h-full rounded-full bg-[#1A365D] dark:bg-blue-11 transition-all duration-500"
                :style="{ width: barWidth(ch.count) }"
              />
            </div>
            <span class="text-xs font-medium text-n-slate-12 tabular-nums w-8 text-right flex-shrink-0">
              {{ ch.count }}
            </span>
          </div>
        </div>
        <p v-else class="text-xs text-n-slate-9">Sin datos de canales.</p>
      </div>
    </div>
  </div>
</template>
