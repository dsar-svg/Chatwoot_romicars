<script setup>
import { ref } from 'vue';

const props = defineProps({
  productsTop: { type: Array, default: () => [] },
  productsBottom: { type: Array, default: () => [] },
  available: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const activeTab = ref('top');

function productName(p) {
  return p.nombre || p.descripcion || p.name || 'Producto sin nombre';
}

function productQty(p) {
  return p.cantidad_vendida ?? p.cantidad ?? p.qty ?? 0;
}

function productAmount(p) {
  const amt = p.monto_facturado ?? p.monto ?? p.total ?? 0;
  return Number(amt).toLocaleString('es-VE', { style: 'currency', currency: 'USD', minimumFractionDigits: 2 });
}
</script>

<template>
  <div class="bg-white dark:bg-n-solid-2 rounded-xl border border-n-weak p-5">
    <div class="flex items-center gap-2 mb-4">
      <span class="i-lucide-package size-4 text-[#361E2C] dark:text-ruby-9" />
      <h2 class="text-sm font-semibold text-n-slate-12">Productos Profit</h2>
      <span
        v-if="!available && !loading"
        class="ml-auto text-[10px] font-medium px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-9"
      >
        Sin conexión
      </span>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 mb-4 bg-n-alpha-1 rounded-lg p-1 w-fit">
      <button
        class="text-xs font-medium px-3 py-1.5 rounded-md transition-colors"
        :class="activeTab === 'top'
          ? 'bg-white dark:bg-n-solid-3 text-n-slate-12 shadow-sm'
          : 'text-n-slate-10 hover:text-n-slate-11'"
        @click="activeTab = 'top'"
      >
        Más vendidos
      </button>
      <button
        class="text-xs font-medium px-3 py-1.5 rounded-md transition-colors"
        :class="activeTab === 'bottom'
          ? 'bg-white dark:bg-n-solid-3 text-n-slate-12 shadow-sm'
          : 'text-n-slate-10 hover:text-n-slate-11'"
        @click="activeTab = 'bottom'"
      >
        Menos vendidos
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-3 animate-pulse">
      <div v-for="i in 4" :key="i" class="flex items-center gap-3">
        <div class="h-3 w-4 bg-n-alpha-2 rounded" />
        <div class="flex-1 h-3 bg-n-alpha-2 rounded" />
        <div class="h-3 w-16 bg-n-alpha-2 rounded" />
      </div>
    </div>

    <!-- No Profit API -->
    <div v-else-if="!available" class="text-center py-8">
      <span class="i-lucide-plug-zap size-8 text-n-slate-9 mx-auto block mb-2" />
      <p class="text-sm text-n-slate-11 font-medium">Profit API no configurada</p>
      <p class="text-xs text-n-slate-9 mt-1">
        Agrega PROFIT_API_URL, PROFIT_API_USER y PROFIT_API_PASSWORD al entorno del servidor.
      </p>
    </div>

    <!-- Products list -->
    <div v-else>
      <div
        v-for="(product, idx) in (activeTab === 'top' ? productsTop : productsBottom)"
        :key="idx"
        class="flex items-center gap-3 py-2.5 border-b border-n-weak last:border-0"
      >
        <span
          class="text-[11px] font-bold tabular-nums w-5 text-center flex-shrink-0"
          :class="activeTab === 'top' && idx < 3 ? 'text-amber-500' : 'text-n-slate-9'"
        >
          {{ idx + 1 }}
        </span>
        <div class="flex-1 min-w-0">
          <p class="text-sm text-n-slate-12 truncate">{{ productName(product) }}</p>
          <p class="text-xs text-n-slate-9">{{ productQty(product) }} unidades</p>
        </div>
        <p class="text-sm font-semibold text-n-slate-12 tabular-nums flex-shrink-0">
          {{ productAmount(product) }}
        </p>
      </div>

      <p v-if="!(activeTab === 'top' ? productsTop : productsBottom).length" class="text-xs text-n-slate-9 text-center py-6">
        Sin datos disponibles.
      </p>
    </div>
  </div>
</template>
