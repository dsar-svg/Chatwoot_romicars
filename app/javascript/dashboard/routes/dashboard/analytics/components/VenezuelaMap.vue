<script setup>
import { computed, ref } from 'vue';
import {
  MAP_W,
  MAP_H,
  toSvg,
  VENEZUELA_PATH,
} from 'dashboard/helper/venezuelaGeo';
import { toHeatPoints } from 'dashboard/helper/venezuelaCities';

const props = defineProps({
  locations: { type: Array, default: () => [] },
  withoutCity: { type: Number, default: 0 },
  loading: { type: Boolean, default: false },
});

const hovered = ref(null);

const points = computed(() => {
  const heat = toHeatPoints(props.locations);
  const max = heat.length ? heat[0].count : 0;

  return heat.map(point => ({
    ...point,
    ...toSvg(point.lat, point.lng),
    // Square root so a town with ten times the contacts reads as bigger, not as a blob
    // covering half the country.
    radius: 8 + 24 * Math.sqrt(point.count / max),
  }));
});

const plotted = computed(() =>
  points.value.reduce((total, point) => total + point.count, 0)
);

// Rows the API returned that no place in the table matched — a typo, a town that is not
// listed, or something that is not a city at all. Silently dropping them would make the
// map look complete when it is not.
const unmatched = computed(() => {
  const counted = props.locations.reduce(
    (total, { count }) => total + (Number(count) || 0),
    0
  );
  return counted - plotted.value;
});
</script>

<template>
  <div class="bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5">
    <div class="flex items-center gap-2 mb-4">
      <span class="i-lucide-map-pin size-4 text-n-accent" />
      <h2 class="text-sm font-semibold text-n-slate-12">
        ¿De dónde nos escriben?
      </h2>
      <span class="ml-auto text-xs text-n-slate-9">
        {{ plotted }} contactos ubicados
      </span>
    </div>

    <div v-if="loading" class="h-64 bg-n-alpha-1 rounded-lg animate-pulse" />

    <div v-else class="relative overflow-hidden rounded-lg bg-n-blue-2">
      <svg
        :viewBox="`0 0 ${MAP_W} ${MAP_H}`"
        class="w-full h-auto max-h-[340px]"
        @mouseleave="hovered = null"
      >
        <defs>
          <filter id="romicars-heat-blur">
            <feGaussianBlur stdDeviation="7" />
          </filter>
        </defs>

        <path
          :d="VENEZUELA_PATH"
          class="fill-n-blue-4 stroke-n-blue-7"
          stroke-width="1.5"
          stroke-linejoin="round"
          fill-rule="evenodd"
        />

        <!-- Heat first, blurred as one layer so neighbouring towns bleed into each other
             the way a heat map should. -->
        <g filter="url(#romicars-heat-blur)" class="pointer-events-none">
          <circle
            v-for="point in points"
            :key="`heat-${point.lat}-${point.lng}`"
            :cx="point.x"
            :cy="point.y"
            :r="point.radius"
            class="fill-n-ruby-9"
            opacity="0.45"
          />
        </g>

        <circle
          v-for="point in points"
          :key="`dot-${point.lat}-${point.lng}`"
          :cx="point.x"
          :cy="point.y"
          r="3"
          class="fill-n-slate-12 cursor-pointer"
          @mouseenter="hovered = point"
        />

        <g v-if="hovered" class="pointer-events-none">
          <rect
            :x="Math.min(hovered.x + 8, MAP_W - 130)"
            :y="hovered.y - 26"
            width="126"
            height="34"
            rx="4"
            class="fill-n-solid-3"
            opacity="0.96"
          />
          <text
            :x="Math.min(hovered.x + 14, MAP_W - 124)"
            :y="hovered.y - 12"
            font-size="10"
            font-weight="600"
            class="fill-n-slate-12"
          >
            {{ hovered.labels[0] }}
          </text>
          <text
            :x="Math.min(hovered.x + 14, MAP_W - 124)"
            :y="hovered.y + 2"
            font-size="9"
            class="fill-n-slate-10"
          >
            {{ hovered.count }} contactos
          </text>
        </g>
      </svg>

      <!-- A caption along the bottom rather than a panel over the map. The map is the
           point of the card even when there is nothing plotted on it yet. -->
      <p
        v-if="!points.length || withoutCity || unmatched"
        class="absolute inset-x-0 bottom-0 py-2 text-center text-xs text-n-slate-11 bg-n-alpha-2 backdrop-blur-sm"
      >
        <template v-if="!points.length">
          Ningún contacto tiene ciudad registrada todavía
        </template>
        <template v-else>
          {{ withoutCity + unmatched }} contactos sin ciudad reconocida
        </template>
      </p>
    </div>
  </div>
</template>
