<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { setColorTheme } from 'dashboard/helper/themeHelper';

// One click between light and dark, always in sight. The profile menu still has the
// three-way choice (light, dark, follow the system) for whoever wants "auto" back.
const { t } = useI18n();

const currentlyDark = () => {
  const scheme = LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) || 'auto';
  if (scheme === 'auto') {
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  return scheme === 'dark';
};

const isDark = ref(currentlyDark());

const toggle = () => {
  isDark.value = !currentlyDark();
  LocalStorage.set(
    LOCAL_STORAGE_KEYS.COLOR_SCHEME,
    isDark.value ? 'dark' : 'light'
  );
  setColorTheme(isDark.value);
};
</script>

<template>
  <Button
    v-tooltip.top="
      isDark ? t('SIDEBAR_ITEMS.LIGHT_MODE') : t('SIDEBAR_ITEMS.DARK_MODE')
    "
    :icon="isDark ? 'i-lucide-sun' : 'i-lucide-moon'"
    :aria-label="
      isDark ? t('SIDEBAR_ITEMS.LIGHT_MODE') : t('SIDEBAR_ITEMS.DARK_MODE')
    "
    variant="ghost"
    color="slate"
    size="sm"
    class="flex-shrink-0"
    @click="toggle"
  />
</template>
