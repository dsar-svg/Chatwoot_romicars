<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  label: { type: String, required: true },
  icon: { type: String, default: '' },
  active: { type: Boolean, default: false },
});

defineEmits(['select']);
</script>

<template>
  <button
    type="button"
    class="flex items-center w-full gap-3 px-4 py-3 text-sm text-start text-n-slate-12 active:bg-n-alpha-2"
    @click="$emit('select')"
  >
    <Icon
      v-if="icon"
      :icon="icon"
      class="flex-shrink-0 size-4 text-n-slate-11"
    />
    <span class="flex-1 truncate">{{ label }}</span>
    <Icon
      v-if="active"
      icon="i-lucide-check"
      class="flex-shrink-0 size-4 text-n-brand"
    />
  </button>
</template>
