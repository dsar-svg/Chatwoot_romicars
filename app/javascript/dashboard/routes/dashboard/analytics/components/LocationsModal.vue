<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import api from 'dashboard/api/romicarsAnalytics';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper.js';
import { groupByState } from 'dashboard/helper/venezuelaCities';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  locations: { type: Array, default: () => [] },
});

const emit = defineEmits(['close']);

const router = useRouter();

const states = computed(() => groupByState(props.locations));
const openState = ref(null);
const city = ref(null);
const contacts = ref([]);
const loadingContacts = ref(false);

watch(
  () => props.show,
  show => {
    if (!show) return;
    openState.value = null;
    city.value = null;
  }
);

async function showCity(selected) {
  city.value = selected;
  contacts.value = [];
  loadingContacts.value = true;
  try {
    const { data } = await api.getCityContacts(selected.labels);
    contacts.value = data.contacts || [];
  } catch (e) {
    contacts.value = [];
  } finally {
    loadingContacts.value = false;
  }
}

function toggleState(state) {
  openState.value = openState.value === state ? null : state;
}

function goToContact(contact) {
  const accountId = router.currentRoute.value.params.accountId;
  const path = contact.conversation_id
    ? frontendURL(conversationUrl({ accountId, id: contact.conversation_id }))
    : `/app/accounts/${accountId}/contacts/${contact.id}`;
  router.push({ path });
  emit('close');
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="show"
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm"
        @click="emit('close')"
      />
      <div
        class="relative bg-n-solid-1 rounded-xl border border-n-strong shadow-2xl w-full max-w-lg max-h-[70vh] flex flex-col z-10"
      >
        <div class="flex items-center gap-2 px-5 py-4 border-b border-n-weak">
          <button
            v-if="city"
            class="flex items-center justify-center size-8 rounded-lg hover:bg-n-alpha-2"
            @click="city = null"
          >
            <Icon icon="i-lucide-arrow-left" class="size-4 text-n-slate-11" />
          </button>
          <div class="min-w-0">
            <h3 class="text-base font-semibold text-n-slate-12 truncate">
              {{ city ? city.name : 'Contactos por estado' }}
            </h3>
            <p class="text-xs text-n-slate-10 mt-0.5">
              {{
                city
                  ? `${city.count} contactos`
                  : 'Toca una ciudad para ver sus contactos'
              }}
            </p>
          </div>
          <button
            class="ml-auto flex items-center justify-center size-8 rounded-lg hover:bg-n-alpha-2"
            @click="emit('close')"
          >
            <Icon icon="i-lucide-x" class="size-4 text-n-slate-11" />
          </button>
        </div>

        <div class="flex-1 overflow-y-auto">
          <template v-if="city">
            <div
              v-if="loadingContacts"
              class="py-12 text-center text-sm text-n-slate-10"
            >
              Cargando...
            </div>
            <div
              v-else-if="!contacts.length"
              class="py-12 text-center text-sm text-n-slate-10"
            >
              Sin resultados
            </div>
            <button
              v-for="contact in contacts"
              :key="contact.id"
              class="flex w-full items-center gap-3 px-5 py-3 text-left border-b border-n-weak last:border-0 hover:bg-n-alpha-2"
              @click="goToContact(contact)"
            >
              <span class="text-sm font-medium text-n-slate-12 truncate">
                {{ contact.name || '—' }}
              </span>
              <span class="ml-auto text-xs text-n-slate-10 shrink-0">
                {{ contact.phone_number || '' }}
              </span>
            </button>
          </template>

          <template v-else>
            <div
              v-if="!states.length"
              class="py-12 text-center text-sm text-n-slate-10"
            >
              Ningún contacto tiene ciudad registrada todavía
            </div>
            <div
              v-for="group in states"
              :key="group.state"
              class="border-b border-n-weak last:border-0"
            >
              <button
                class="flex w-full items-center gap-2 px-5 py-3 text-left hover:bg-n-alpha-2"
                @click="toggleState(group.state)"
              >
                <Icon
                  :icon="
                    openState === group.state
                      ? 'i-lucide-chevron-down'
                      : 'i-lucide-chevron-right'
                  "
                  class="size-4 text-n-slate-10"
                />
                <span class="text-sm font-medium text-n-slate-12">
                  {{ group.state }}
                </span>
                <span class="ml-auto text-xs text-n-slate-10">
                  {{ group.count }}
                </span>
              </button>
              <div v-if="openState === group.state" class="pb-2">
                <button
                  v-for="item in group.cities"
                  :key="item.name"
                  class="flex w-full items-center gap-2 py-2 pl-11 pr-5 text-left hover:bg-n-alpha-2"
                  @click="showCity(item)"
                >
                  <span class="text-sm text-n-slate-11">{{ item.name }}</span>
                  <span class="ml-auto text-xs text-n-slate-10">
                    {{ item.count }}
                  </span>
                </button>
              </div>
            </div>
          </template>
        </div>

        <div class="flex justify-end px-5 py-3 border-t border-n-weak">
          <Button slate ghost label="Cerrar" @click="emit('close')" />
        </div>
      </div>
    </div>
  </Teleport>
</template>
