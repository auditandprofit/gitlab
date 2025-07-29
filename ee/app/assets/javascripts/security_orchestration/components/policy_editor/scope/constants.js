import { s__ } from '~/locale';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const PROJECTS_WITH_FRAMEWORK = 'projects_with_framework';
export const ALL_PROJECTS_IN_GROUP = 'all_projects_in_group';
export const SPECIFIC_PROJECTS = 'specific_projects';
export const ALL_PROJECTS_IN_LINKED_GROUPS = 'all_projects_in_linked_groups';

export const PROJECT_SCOPE_TYPE_TEXTS = {
  [PROJECTS_WITH_FRAMEWORK]: s__('SecurityOrchestration|projects with compliance frameworks'),
  [ALL_PROJECTS_IN_GROUP]: s__('SecurityOrchestration|all projects in this group'),
  [SPECIFIC_PROJECTS]: s__('SecurityOrchestration|specific projects'),
  [ALL_PROJECTS_IN_LINKED_GROUPS]: s__('SecurityOrchestration|all projects in the linked groups'),
};

const CSP_SCOPE_TYPE_TEXTS_WITHOUT_GROUP = {
  [PROJECTS_WITH_FRAMEWORK]: s__('SecurityOrchestration|projects with compliance frameworks'),
  [ALL_PROJECTS_IN_GROUP]: s__('SecurityOrchestration|all projects in this instance'),
  [SPECIFIC_PROJECTS]: s__('SecurityOrchestration|specific projects'),
};

export const CSP_SCOPE_TYPE_TEXTS = {
  ...CSP_SCOPE_TYPE_TEXTS_WITHOUT_GROUP,
  [ALL_PROJECTS_IN_LINKED_GROUPS]: s__('SecurityOrchestration|all projects in the groups'),
};

export const PROJECT_SCOPE_TYPE_LISTBOX_ITEMS = mapToListboxItems(PROJECT_SCOPE_TYPE_TEXTS);

export const CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS = mapToListboxItems(
  CSP_SCOPE_TYPE_TEXTS_WITHOUT_GROUP,
);

export const CSP_SCOPE_TYPE_LISTBOX_ITEMS = mapToListboxItems(CSP_SCOPE_TYPE_TEXTS);

export const WITHOUT_EXCEPTIONS = 'without_exceptions';
export const EXCEPT_PROJECTS = 'except_projects';
export const EXCEPT_GROUPS = 'except_groups';
export const INCLUDING = 'including';
export const EXCLUDING = 'excluding';
export const COMPLIANCE_FRAMEWORKS_KEY = 'compliance_frameworks';
export const PROJECTS_KEY = 'projects';
export const GROUPS_KEY = 'groups';

export const EXCEPTION_TYPE_TEXTS = {
  [WITHOUT_EXCEPTIONS]: s__('SecurityOrchestration|without exceptions'),
  [EXCEPT_PROJECTS]: s__('SecurityOrchestration|except projects'),
};

export const GROUP_EXCEPTION_TYPE_TEXTS = {
  [WITHOUT_EXCEPTIONS]: s__('SecurityOrchestration|without exceptions'),
  [EXCEPT_GROUPS]: s__('SecurityOrchestration|except groups'),
};

export const EXCEPTION_TYPE_LISTBOX_ITEMS = mapToListboxItems(EXCEPTION_TYPE_TEXTS);
export const GROUP_EXCEPTION_TYPE_LISTBOX_ITEMS = mapToListboxItems(GROUP_EXCEPTION_TYPE_TEXTS);
