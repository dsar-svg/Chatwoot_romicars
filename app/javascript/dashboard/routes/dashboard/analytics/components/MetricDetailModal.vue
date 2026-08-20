<script setup>
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper.js';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  type: { type: String, default: '' },
  label: { type: String, default: '' },
  items: { type: Array, default: () => [] },
  total: { type: Number, default: 0 },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['close']);

const router = useRouter();

const statusColors = {
  'Abierta': 'bg-n-green-3 text-n-green-11',
  'Pendiente': 'bg-n-amber-3 text-n-amber-11',
  'Resuelta': 'bg-n-blue-3 text-n-blue-11',
  'Nuevo': 'bg-n-blue-3 text-n-blue-11',
};

function getStatusClass(status) {
  return statusColors[status] || 'bg-n-alpha-2 text-n-slate-11';
}

function goToItem(item) {
  const accountId = router.currentRoute.value.params.accountId;

  if (props.type === 'new_today') {
    const path = `/app/accounts/${accountId}/contacts/${item.id}`;
    router.push({ path });
  } else {
    const path = frontendURL(
      conversationUrl({ accountId, id: item.id })
    );
    router.push({ path });
  }
  emit('close');
}

function formatDate(dateStr) {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  return d.toLocaleDateString('es-VE', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
}
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="show"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        @click.self="emit('close')"
      >
        <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" @click="emit('close')" />
        <div class="relative bg-n-solid-1 rounded-xl border border-n-strong shadow-2xl w-full max-w-lg max-h-[70vh] flex flex-col z-10">
          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-n-weak">
            <div>
              <h3 class="text-base font-semibold text-n-slate-12">{{ label }}</h3>
              <p class="text-xs text-n-slate-10 mt-0.5">{{ total }} resultado{{ total !== 1 ? 's' : '' }}</p>
            </div>
            <button
              class="flex items-center justify-center size-8 rounded-lg hover:bg-n-alpha-2 transition-colors"
              @click="emit('close')"
            >
              <Icon icon="i-lucide-x" class="size-4 text-n-slate-11" />
            </button>
          </div>

          <!-- Content -->
          <div class="flex-1 overflow-y-auto">
            <!-- Loading -->
            <div v-if="loading" class="flex items-center justify-center py-12">
              <span class="text-sm text-n-slate-10">Cargando...</span>
            </div>

            <!-- Empty -->
            <div v-else-if="items.length === 0" class="flex flex-col items-center justify-center py-12 gap-2">
              <Icon icon="i-lucide-inbox" class="size-8 text-n-slate-8" />
              <span class="text-sm text-n-slate-10">Sin resultados</span>
            </div>

            <!-- Table -->
            <table v-else class="w-full">
              <thead>
                <tr class="border-b border-n-weak">
                  <th class="text-left text-[10px] font-semibold uppercase tracking-wide text-n-slate-10 px-5 py-2.5">
                    {{ type === 'new_today' ? 'Contacto' : 'Contacto' }}
                  </th>
                  <th class="text-left text-[10px] font-semibold uppercase tracking-wide text-n-slate-10 px-5 py-2.5">
                    {{ type === 'new_today' ? 'Registrado' : 'Estado' }}
                  </th>
                  <th v-if="type !== 'new_today'" class="text-left text-[10px] font-semibold uppercase tracking-wide text-n-slate-10 px-5 py-2.5">
                    Agente
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="item in items"
                  :key="item.id"
                  class="border-b border-n-weak last:border-0 hover:bg-n-alpha-2 cursor-pointer transition-colors"
                  @click="goToItem(item)"
                >
                  <td class="px-5 py-3">
                    <span class="text-sm font-medium text-n-slate-12">
                      {{ item.contact_name || '—' }}
                    </span>
                    <span class="text-[10px] text-n-slate-10 ml-1.5">#{{ item.id }}</span>
                  </td>
                  <td class="px-5 py-3">
                    <span v-if="type === 'new_today'" class="text-xs text-n-slate-11">
                      {{ formatDate(item.created_at) }}
                    </span>
                    <span
                      v-else
                      class="text-[10px] font-medium px-2 py-0.5 rounded-full"
                      :class="getStatusClass(item.status)"
                    >
                      {{ item.status }}
                    </span>
                  </td>
                  <td v-if="type !== 'new_today'" class="px-5 py-3">
                    <span class="text-sm text-n-slate-11">
                      {{ item.agent_name || '—' }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Footer -->
          <div class="flex justify-end px-5 py-3 border-t border-n-weak">
            <Button
              slate
              ghost
              label="Cerrar"
              @click="emit('close')"
            />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}
.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}
</style>
