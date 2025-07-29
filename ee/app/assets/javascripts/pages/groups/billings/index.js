import initTargetedMessages from 'ee/admin/init_targeted_message';
import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initSubscriptions from 'ee/billings/subscriptions';

initSubscriptions();
shouldQrtlyReconciliationMount();
initTargetedMessages();
