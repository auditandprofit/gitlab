/* eslint-disable no-new */

import mountComponents from 'ee/registrations/groups/new';
import Group from '~/group';
import { trackCombinedGroupProjectForm, trackProjectImport } from 'ee/google_tag_manager';
import FormErrorTracker from '~/pages/shared/form_error_tracker';

new Group();
mountComponents();
trackCombinedGroupProjectForm();
trackProjectImport();

// Warning: run after all input initializations
new FormErrorTracker();
