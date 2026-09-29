<script setup>
// Bottom sheet: the phone-sized stand-in for the desktop dropdowns.
defineProps({
  title: { type: String, default: '' },
});

const show = defineModel('show', { type: Boolean, default: false });
</script>

<template>
  <Teleport to="body">
    <div
      v-if="show"
      class="fixed inset-0 z-50 flex flex-col justify-end bg-n-alpha-black2"
      @click.self="show = false"
    >
      <div
        class="flex flex-col max-h-[80vh] rounded-t-2xl bg-n-solid-2 pb-[env(safe-area-inset-bottom)]"
      >
        <div class="flex justify-center pt-2">
          <span class="w-10 h-1 rounded-full bg-n-slate-6" />
        </div>
        <h2
          v-if="title"
          class="px-4 pt-3 pb-2 text-sm font-medium text-n-slate-12"
        >
          {{ title }}
        </h2>
        <div class="flex flex-col overflow-y-auto">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>
