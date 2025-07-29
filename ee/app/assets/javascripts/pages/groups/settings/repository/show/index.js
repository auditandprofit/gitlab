/* eslint-disable no-new */
import initSettingsPanels from '~/settings_panels';
import ProtectedBranchEditList from 'ee/protected_branches/protected_branch_edit_list';
import ProtectedBranchCreate from '~/protected_branches/protected_branch_create';

const PROTECTED_BRANCHES_SELECTOR = '#js-protected-branches-settings';

initSettingsPanels();
new ProtectedBranchCreate({ hasLicense: true, sectionSelector: PROTECTED_BRANCHES_SELECTOR });
new ProtectedBranchEditList(PROTECTED_BRANCHES_SELECTOR);
