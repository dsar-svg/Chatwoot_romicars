/**
 * Composable for branding-related utilities
 * Provides methods to customize text with installation-specific branding
 */
import { useMapGetter } from 'dashboard/composables/store.js';

export function useBranding() {
  const globalConfig = useMapGetter('globalConfig/get');
  /**
   * Replaces standalone "Chatwoot" (any casing) in text with the installation name
   * from global config. Only matches whole words to avoid breaking URLs or code.
   * @param {string} text - The text to process
   * @returns {string} - Text with "Chatwoot" replaced by installation name
   */
  const replaceInstallationName = text => {
    if (!text) return text;

    const installationName = globalConfig.value?.installationName;
    if (!installationName) return text;

    return text.replace(/\bchatwoot\b/gi, installationName);
  };

  return {
    replaceInstallationName,
  };
}
