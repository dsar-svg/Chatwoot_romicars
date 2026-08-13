<script setup>
import { computed, ref } from 'vue';

const props = defineProps({
  customers: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

// Simplified Venezuela GeoJSON bounding box:
// Lat: 0.6 to 12.2 (N)  /  Lng: -73.4 to -59.8 (W)
const MAP_W = 500;
const MAP_H = 300;
const LAT_MIN = 0.6;
const LAT_MAX = 12.2;
const LNG_MIN = -73.4;
const LNG_MAX = -59.8;

function toSvg(lat, lng) {
  const x = ((lng - LNG_MIN) / (LNG_MAX - LNG_MIN)) * MAP_W;
  const y = MAP_H - ((lat - LAT_MIN) / (LAT_MAX - LAT_MIN)) * MAP_H;
  return { x, y };
}

// Simplified Venezuela outline (clockwise, major coastal points)
const venezuelaPath = `
  M 380,10 L 410,20 L 440,35 L 460,28 L 480,40 L 495,55 L 498,80 L 490,95
  L 470,100 L 455,115 L 445,135 L 430,150 L 420,165 L 415,185 L 400,200
  L 390,215 L 370,225 L 355,240 L 335,248 L 310,250 L 285,252 L 260,248
  L 235,240 L 215,230 L 200,215 L 195,200 L 190,185 L 180,170 L 165,160
  L 150,148 L 135,135 L 120,125 L 105,115 L 90,105 L 75,95 L 60,85
  L 45,75 L 30,65 L 15,55 L 10,40 L 18,28 L 32,20 L 55,15 L 80,10
  L 110,8 L 145,6 L 180,5 L 215,4 L 250,3 L 285,4 L 320,6 L 350,8 Z
`;

const tooltip = ref(null);
const tooltipPos = ref({ x: 0, y: 0 });

const dots = computed(() => {
  return props.customers
    .filter(c => c.lat && c.lng)
    .map(c => ({ ...toSvg(Number(c.lat), Number(c.lng)), name: c.nombre || c.name || 'Cliente', city: c.ciudad || c.city || '' }));
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
      <span class="i-lucide-map-pin size-4 text-[#361E2C] dark:text-ruby-9" />
      <h2 class="text-sm font-semibold text-n-slate-12">Ubicación de Clientes</h2>
      <span class="ml-auto text-xs text-n-slate-9">{{ customers.length }} clientes</span>
    </div>

    <div v-if="loading" class="h-64 bg-n-alpha-1 rounded-lg animate-pulse" />

    <div v-else class="relative overflow-hidden rounded-lg bg-gradient-to-br from-[#1A365D]/5 to-[#1A365D]/10 dark:from-[#1A365D]/20 dark:to-[#0F1923]">
      <svg
        :viewBox="`0 0 ${MAP_W} ${MAP_H}`"
        class="w-full h-auto"
        style="max-height: 280px"
        @mouseleave="hideTooltip"
      >
        <!-- Country outline -->
        <path
          :d="venezuelaPath"
          class="fill-[#1A365D]/15 dark:fill-[#1A365D]/30 stroke-[#1A365D]/40 dark:stroke-blue-11/30"
          stroke-width="1.5"
          stroke-linejoin="round"
        />

        <!-- Customer dots -->
        <g v-for="(dot, i) in dots" :key="i">
          <circle
            :cx="dot.x"
            :cy="dot.y"
            r="8"
            class="fill-[#361E2C]/10 dark:fill-ruby-9/10"
          />
          <circle
            :cx="dot.x"
            :cy="dot.y"
            r="5"
            class="fill-[#361E2C]/30 dark:fill-ruby-9/30"
          />
          <circle
            :cx="dot.x"
            :cy="dot.y"
            r="2.5"
            class="fill-[#361E2C] dark:fill-ruby-9 cursor-pointer"
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
          <text :x="tooltipPos.x + 14" :y="tooltipPos.y - 6" font-size="9" class="fill-n-slate-12" font-weight="600">
            {{ tooltip.name }}
          </text>
          <text :x="tooltipPos.x + 14" :y="tooltipPos.y + 8" font-size="8" class="fill-n-slate-10">
            {{ tooltip.city }}
          </text>
        </g>
      </svg>

      <!-- No customers placeholder -->
      <div v-if="!dots.length" class="absolute inset-0 flex flex-col items-center justify-center">
        <span class="i-lucide-map size-10 text-n-slate-9 mb-2" />
        <p class="text-xs text-n-slate-9">
          {{ customers.length ? 'Los clientes no tienen coordenadas' : 'Sin datos de clientes (Profit API)' }}
        </p>
      </div>
    </div>
  </div>
</template>
