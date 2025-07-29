import '~/pages/groups/show';
import initTargetedMessages from 'ee/admin/init_targeted_message';
import initGroupAnalytics from 'ee/analytics/group_analytics/group_analytics_bundle';
import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initVueAlerts from '~/vue_alerts';
import initTierBadgeTrigger from 'ee/groups/init_tier_badge_trigger';
import initEnableDuoBanner from 'ee/ai/init_enable_duo_banner';

initGroupAnalytics();
initVueAlerts();
shouldQrtlyReconciliationMount();
initTierBadgeTrigger();
initEnableDuoBanner();
initTargetedMessages();
