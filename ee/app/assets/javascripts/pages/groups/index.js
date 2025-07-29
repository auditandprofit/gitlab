import { initHandRaiseLead } from 'ee/hand_raise_leads/hand_raise_lead';
import { initAiSettings } from 'ee/ai/settings/index';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initHandRaiseLead();
initSimpleApp(
  '#js-amazon-q-settings',
  () =>
    import(
      /* webpackChunkName: 'amazonQGroupSettings' */ 'ee/amazon_q_settings/components/group_settings_app.vue'
    ),
);
initAiSettings('js-ai-settings', AiGroupSettings);
