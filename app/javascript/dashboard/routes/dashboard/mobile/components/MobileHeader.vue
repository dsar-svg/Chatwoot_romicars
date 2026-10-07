<script setup>
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import ThemeToggleButton from 'dashboard/components-next/sidebar/ThemeToggleButton.vue';

const props = defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  // Route to go back to; falls back to history when the page was opened directly.
  backTo: { type: Object, default: null },
});

const router = useRouter();

const goBack = () => {
  if (window.history.state?.back) {
    router.back();
  } else if (props.backTo) {
    router.push(props.backTo);
  }
};
</script>

<template>
  <header
    class="flex items-center flex-shrink-0 gap-2 px-3 min-h-14 border-b border-n-weak bg-n-solid-1 pt-[env(safe-area-inset-top)]"
  >
    <Button
      v-if="backTo"
      icon="i-lucide-chevron-left"
      variant="ghost"
      color="slate"
      size="sm"
      :aria-label="$t('MOBILE.BACK')"
      @click="goBack"
    />
    <slot name="start" />
    <div class="flex flex-col flex-1 min-w-0">
      <h1 class="text-base font-medium truncate text-n-slate-12">
        {{ title }}
      </h1>
      <p v-if="subtitle" class="text-xs truncate text-n-slate-11">
        {{ subtitle }}
      </p>
    </div>
    <slot name="end" />
    <ThemeToggleButton />
  </header>
</template>
