import '~/pages/admin/dashboard';
import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initEnableDuoBannerSM from 'ee/ai/init_enable_duo_banner_sm';

shouldQrtlyReconciliationMount();
initEnableDuoBannerSM();
