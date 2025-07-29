import { initProductAnalyticsSettingsInstrumentationInstructions } from 'ee/product_analytics/onboarding';
import initSettingsPanels from '~/settings_panels';
import { initProjectSelects } from '~/vue_shared/components/entity_select/init_project_selects';
import { initInputCopyToggleVisibility } from '~/vue_shared/components/input_copy_toggle_visibility';

initProductAnalyticsSettingsInstrumentationInstructions();
initSettingsPanels();
initProjectSelects();
initInputCopyToggleVisibility();
