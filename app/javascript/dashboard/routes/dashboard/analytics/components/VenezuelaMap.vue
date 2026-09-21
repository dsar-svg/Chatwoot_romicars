<script setup>
import { computed, ref } from 'vue';
import {
  MAP_W,
  MAP_H,
  toSvg,
  VENEZUELA_PATH,
} from 'dashboard/helper/venezuelaGeo';

const props = defineProps({
  customers: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

const tooltip = ref(null);
const tooltipPos = ref({ x: 0, y: 0 });

const dots = computed(() => {
  return props.customers
    .filter(c => c.lat && c.lng)
    .map(c => ({
      ...toSvg(Number(c.lat), Number(c.lng)),
      name: c.nombre || c.name || 'Cliente',
      city: c.ciudad || c.city || '',
    }));
});

function showTooltip(evt, dot) {
  tooltip.value = dot;
  tooltipPos.value = { x: evt.offsetX, y: evt.offsetY };
}

function hideTooltip() {
  tooltip.value = null;
}
</script>

<template>
  <div class="bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5">
    <div class="flex items-center gap-2 mb-4">
      <span class="i-lucide-map-pin size-4 text-n-accent" />
      <h2 class="text-sm font-semibold text-n-slate-12">
        Ubicación de Clientes
      </h2>
      <span class="ml-auto text-xs text-n-slate-9"
        >{{ customers.length }} clientes</span
      >
    </div>

    <div v-if="loading" class="h-64 bg-n-alpha-1 rounded-lg animate-pulse" />

    <div v-else class="relative overflow-hidden rounded-lg bg-n-blue-2">
      <svg
        :viewBox="`0 0 ${MAP_W} ${MAP_H}`"
        class="w-full h-auto max-h-[340px]"
        @mouseleave="hideTooltip"
      >
        <!-- Country outline -->
        <path
          :d="VENEZUELA_PATH"
          class="fill-n-blue-4 stroke-n-blue-7"
          stroke-width="1.5"
          stroke-linejoin="round"
        />

        <!-- Customer dots -->
        <g v-for="(dot, i) in dots" :key="i">
          <circle :cx="dot.x" :cy="dot.y" r="8" class="fill-n-accent/10" />
          <circle :cx="dot.x" :cy="dot.y" r="5" class="fill-n-accent/30" />
          <circle
            :cx="dot.x"
            :cy="dot.y"
            r="2.5"
            class="fill-n-accent cursor-pointer"
            @mouseenter="showTooltip($event, dot)"
          />
        </g>

        <!-- Tooltip -->
        <g v-if="tooltip">
          <rect
            :x="tooltipPos.x + 8"
            :y="tooltipPos.y - 20"
            width="120"
            height="38"
            rx="4"
            class="fill-n-solid-3"
            opacity="0.95"
          />
          <text
            :x="tooltipPos.x + 14"
            :y="tooltipPos.y - 6"
            font-size="9"
            class="fill-n-slate-12"
            font-weight="600"
          >
            {{ tooltip.name }}
          </text>
          <text
            :x="tooltipPos.x + 14"
            :y="tooltipPos.y + 8"
            font-size="8"
            class="fill-n-slate-10"
          >
            {{ tooltip.city }}
          </text>
        </g>
      </svg>

      <!-- No customers: a caption along the bottom rather than a panel over the map. The
           map is the point of the card even when there is nothing plotted on it yet. -->
      <p
        v-if="!dots.length"
        class="absolute inset-x-0 bottom-0 py-2 text-center text-xs text-n-slate-11 bg-n-alpha-2 backdrop-blur-sm"
      >
        {{
          customers.length
            ? 'Los clientes no tienen coordenadas'
            : 'Sin datos de clientes (Profit API)'
        }}
      </p>
    </div>
  </div>
</template>
