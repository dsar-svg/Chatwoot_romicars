<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper.js';

const props = defineProps({
  perdidas: {
    type: Object,
    default: () => ({
      total: 0,
      resumen: '',
      causas: [],
      patrones: [],
      repuestos_sin_stock: [],
    }),
  },
  ganadas: {
    type: Object,
    default: () => ({
      total: 0,
      resumen: '',
      practicas: [],
      patrones: [],
      tasa_conversion_pct: 0,
      monto_total_usd: 0,
      ticket_promedio_usd: 0,
    }),
  },
  analizadas: { type: Number, default: 0 },
  nuevas: { type: Number, default: 0 },
  source: { type: String, default: 'rules' },
  loading: { type: Boolean, default: false },
});

const route = useRoute();

const causas = computed(() => props.perdidas.causas || []);
const practicas = computed(() => props.ganadas.practicas || []);
const repuestos = computed(() => props.perdidas.repuestos_sin_stock || []);
const perdidasPatrones = computed(() => props.perdidas.patrones || []);
const ganadasPatrones = computed(() => props.ganadas.patrones || []);

// The bar is relative to the biggest reason, not to the total, so a 2-reason split
// still reads as a comparison.
const maxCausa = computed(() =>
  causas.value.reduce((max, causa) => Math.max(max, causa.cantidad), 1)
);

function barWidth(count) {
  return `${(count / maxCausa.value) * 100}%`;
}

// Nothing to show means either the AI never ran, or it ran and found no repeatable
// pattern. Those need different copy: only one of them is something the owner can fix.
const emptyPatternsHint = computed(() =>
  props.source === 'ai'
    ? 'La IA leyó las conversaciones y no encontró un patrón claro en esta corrida.'
    : 'La IA no leyó conversaciones. Configura OPENAI_API_KEY para activar el análisis.'
);

function conversationLink(id) {
  return frontendURL(
    conversationUrl({ accountId: route.params.accountId, id })
  );
}

function money(value) {
  return `$${Number(value || 0).toLocaleString('es-VE', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}
</script>

<template>
  <section>
    <div class="flex items-center justify-between mb-4">
      <div>
        <h2 class="text-sm font-semibold text-n-slate-12">
          Por qué perdemos y qué nos hace ganar
        </h2>
        <p class="text-xs text-n-slate-10 mt-0.5">
          Últimos 30 días · cifras del CRM
          <template v-if="analizadas">
            · {{ analizadas }} conversaciones leídas por la IA
          </template>
          <template v-if="nuevas">
            · {{ nuevas }} nuevas en esta corrida
          </template>
        </p>
      </div>
      <span
        class="text-[10px] font-medium px-2 py-0.5 rounded-full"
        :class="
          source === 'ai'
            ? 'bg-n-blue-3 text-n-blue-11'
            : 'bg-n-alpha-2 text-n-slate-9'
        "
      >
        {{ source === 'ai' ? 'GPT-4o-mini' : 'Reglas' }}
      </span>
    </div>

    <div v-if="loading" class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div
        v-for="i in 2"
        :key="i"
        class="animate-pulse rounded-xl border border-n-weak bg-white dark:bg-n-solid-2 p-5 h-64"
      >
        <div class="h-4 bg-n-alpha-2 rounded w-1/3 mb-4" />
        <div class="space-y-2">
          <div class="h-3 bg-n-alpha-2 rounded w-full" />
          <div class="h-3 bg-n-alpha-2 rounded w-5/6" />
          <div class="h-3 bg-n-alpha-2 rounded w-4/6" />
        </div>
      </div>
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Perdidas -->
      <div
        class="rounded-xl border border-n-weak bg-white dark:bg-n-solid-2 p-5 flex flex-col gap-4"
      >
        <div class="flex items-center gap-2">
          <span class="i-lucide-trending-down size-4 text-n-ruby-11" />
          <h3 class="text-sm font-semibold text-n-slate-12">
            Conversaciones perdidas
          </h3>
          <span
            class="ml-auto text-lg font-bold tabular-nums text-n-ruby-11 leading-none"
          >
            {{ perdidas.total || 0 }}
          </span>
        </div>

        <p
          v-if="perdidas.resumen"
          class="text-xs text-n-slate-11 leading-relaxed"
        >
          {{ perdidas.resumen }}
        </p>

        <p
          v-if="!causas.length"
          class="text-xs text-n-slate-9 py-4 text-center"
        >
          Sin cierres perdidos registrados en el período.
        </p>

        <div v-else class="flex flex-col gap-4">
          <div
            v-for="causa in causas"
            :key="causa.motivo"
            class="flex flex-col gap-1.5"
          >
            <div class="flex items-center gap-2">
              <span
                class="text-xs font-medium text-n-slate-12 w-24 flex-shrink-0"
              >
                {{ causa.etiqueta }}
              </span>
              <div class="flex-1 h-2 bg-n-alpha-2 rounded-full overflow-hidden">
                <div
                  class="h-full bg-n-ruby-9 rounded-full transition-all duration-500"
                  :style="{ width: barWidth(causa.cantidad) }"
                />
              </div>
              <span
                class="text-xs font-semibold tabular-nums text-n-slate-12 w-16 text-right flex-shrink-0"
              >
                {{ causa.cantidad }} · {{ causa.pct }}%
              </span>
            </div>
            <p class="text-xs text-n-slate-11 leading-relaxed">
              {{ causa.diagnostico }}
            </p>
            <div class="flex items-start gap-1.5">
              <span
                class="i-lucide-zap size-3.5 text-n-blue-11 flex-shrink-0 mt-0.5"
              />
              <p class="text-xs text-n-blue-11 leading-relaxed">
                {{ causa.accion }}
              </p>
            </div>
          </div>
        </div>

        <div class="pt-3 border-t border-n-weak">
          <p
            class="text-[10px] font-semibold uppercase tracking-widest text-n-slate-9 mb-2"
          >
            Patrones detectados en los chats
          </p>
          <p v-if="!perdidasPatrones.length" class="text-xs text-n-slate-9">
            {{ emptyPatternsHint }}
          </p>
          <div v-else class="flex flex-col gap-3">
            <div
              v-for="(patron, idx) in perdidasPatrones"
              :key="idx"
              class="flex flex-col gap-1"
            >
              <p class="text-xs font-medium text-n-slate-12 leading-relaxed">
                {{ patron.hallazgo }}
              </p>
              <p
                v-if="patron.evidencia"
                class="text-xs text-n-slate-11 leading-relaxed"
              >
                {{ patron.evidencia }}
              </p>
              <p
                v-if="patron.accion"
                class="text-xs text-n-blue-11 leading-relaxed"
              >
                {{ patron.accion }}
              </p>
              <div
                v-if="patron.conversaciones.length"
                class="flex flex-wrap gap-1.5"
              >
                <router-link
                  v-for="id in patron.conversaciones"
                  :key="id"
                  :to="conversationLink(id)"
                  class="text-[11px] px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-11 hover:text-n-blue-11"
                >
                  #{{ id }}
                </router-link>
              </div>
            </div>
          </div>
        </div>

        <div v-if="repuestos.length" class="pt-3 border-t border-n-weak">
          <p
            class="text-[10px] font-semibold uppercase tracking-widest text-n-slate-9 mb-2"
          >
            Repuestos pedidos sin stock
          </p>
          <div class="flex flex-wrap gap-1.5">
            <span
              v-for="item in repuestos"
              :key="item.producto"
              class="text-[11px] px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-11"
            >
              {{ item.producto }} · {{ item.veces }}
            </span>
          </div>
        </div>
      </div>

      <!-- Ganadas -->
      <div
        class="rounded-xl border border-n-weak bg-white dark:bg-n-solid-2 p-5 flex flex-col gap-4"
      >
        <div class="flex items-center gap-2">
          <span class="i-lucide-trending-up size-4 text-n-teal-11" />
          <h3 class="text-sm font-semibold text-n-slate-12">
            Conversaciones ganadas
          </h3>
          <span
            class="ml-auto text-lg font-bold tabular-nums text-n-teal-11 leading-none"
          >
            {{ ganadas.total || 0 }}
          </span>
        </div>

        <p
          v-if="ganadas.resumen"
          class="text-xs text-n-slate-11 leading-relaxed"
        >
          {{ ganadas.resumen }}
        </p>

        <div class="grid grid-cols-3 gap-2">
          <div class="rounded-lg bg-n-alpha-2 px-3 py-2">
            <p class="text-[10px] text-n-slate-9 uppercase tracking-wide">
              Conversión
            </p>
            <p class="text-sm font-semibold tabular-nums text-n-slate-12">
              {{ ganadas.tasa_conversion_pct || 0 }}%
            </p>
          </div>
          <div class="rounded-lg bg-n-alpha-2 px-3 py-2">
            <p class="text-[10px] text-n-slate-9 uppercase tracking-wide">
              Facturado
            </p>
            <p class="text-sm font-semibold tabular-nums text-n-slate-12">
              {{ money(ganadas.monto_total_usd) }}
            </p>
          </div>
          <div class="rounded-lg bg-n-alpha-2 px-3 py-2">
            <p class="text-[10px] text-n-slate-9 uppercase tracking-wide">
              Ticket
            </p>
            <p class="text-sm font-semibold tabular-nums text-n-slate-12">
              {{ money(ganadas.ticket_promedio_usd) }}
            </p>
          </div>
        </div>

        <p
          v-if="!practicas.length"
          class="text-xs text-n-slate-9 py-4 text-center"
        >
          Todavía no hay diferencia medible entre las ganadas y las perdidas.
        </p>

        <div v-else class="flex flex-col gap-4">
          <div
            v-for="practica in practicas"
            :key="practica.clave"
            class="flex flex-col gap-1.5"
          >
            <div class="flex items-start gap-2">
              <span
                class="i-lucide-check-circle size-3.5 text-n-teal-11 flex-shrink-0 mt-0.5"
              />
              <p class="text-xs font-medium text-n-slate-12 leading-relaxed">
                {{ practica.practica }}
              </p>
            </div>
            <p class="text-xs text-n-slate-11 leading-relaxed pl-5">
              {{ practica.evidencia }}
            </p>
            <div class="flex items-start gap-1.5 pl-5">
              <span
                class="i-lucide-repeat size-3.5 text-n-blue-11 flex-shrink-0 mt-0.5"
              />
              <p class="text-xs text-n-blue-11 leading-relaxed">
                {{ practica.accion }}
              </p>
            </div>
          </div>
        </div>

        <div class="pt-3 border-t border-n-weak">
          <p
            class="text-[10px] font-semibold uppercase tracking-widest text-n-slate-9 mb-2"
          >
            Patrones detectados en los chats
          </p>
          <p v-if="!ganadasPatrones.length" class="text-xs text-n-slate-9">
            {{ emptyPatternsHint }}
          </p>
          <div v-else class="flex flex-col gap-3">
            <div
              v-for="(patron, idx) in ganadasPatrones"
              :key="idx"
              class="flex flex-col gap-1"
            >
              <p class="text-xs font-medium text-n-slate-12 leading-relaxed">
                {{ patron.hallazgo }}
              </p>
              <p
                v-if="patron.evidencia"
                class="text-xs text-n-slate-11 leading-relaxed"
              >
                {{ patron.evidencia }}
              </p>
              <p
                v-if="patron.accion"
                class="text-xs text-n-blue-11 leading-relaxed"
              >
                {{ patron.accion }}
              </p>
              <div
                v-if="patron.conversaciones.length"
                class="flex flex-wrap gap-1.5"
              >
                <router-link
                  v-for="id in patron.conversaciones"
                  :key="id"
                  :to="conversationLink(id)"
                  class="text-[11px] px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-11 hover:text-n-blue-11"
                >
                  #{{ id }}
                </router-link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
