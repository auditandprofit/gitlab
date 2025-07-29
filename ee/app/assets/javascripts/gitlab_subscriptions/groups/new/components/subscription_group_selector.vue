<script>
import {
  GlAccordion,
  GlAccordionItem,
  GlButton,
  GlCard,
  GlCollapsibleListbox,
  GlForm,
  GlFormFields,
  GlAlert,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { formValidators } from '@gitlab/ui/dist/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__, sprintf } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import { slugify } from '~/lib/utils/text_utility';
import { getGroupPathAvailability } from '~/rest_api';
import { subscriptionsCreateGroup } from 'ee_else_ce/rest_api';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { START_RULE, CONTAINS_RULE } from '~/groups/group_name_rules';

const DEBOUNCE_TIMEOUT_DURATION = 1000;
const DEFAULT_GROUP_PATH = '{group}';

const FORM_FIELD_GROUP_ID = 'groupId';
const FORM_FIELD_GROUP_NAME = 'groupName';

export default {
  name: 'SubscriptionGroupSelector',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlButton,
    GlCard,
    GlCollapsibleListbox,
    GlForm,
    GlFormFields,
    GlAlert,
  },
  directives: {
    SafeHtml,
  },
  props: {
    eligibleGroups: {
      type: Array,
      required: false,
      default: () => [],
    },
    plansData: {
      type: Object,
      required: true,
    },
    rootUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isLoading: false,
      groupSlug: DEFAULT_GROUP_PATH,
      shouldShowNewGroupForm: false,
      errorMessage: null,
      currentApiRequestController: null,
      formValues: {
        [FORM_FIELD_GROUP_ID]: null,
        [FORM_FIELD_GROUP_NAME]: null,
      },
    };
  },
  computed: {
    fields() {
      const fields = {};

      if (this.hasEligibleGroups) {
        fields[FORM_FIELD_GROUP_ID] = {
          label: this.$options.i18n.groupSelection.label,
          inputAttrs: {
            placeholder: this.$options.i18n.groupSelection.placeholder,
          },
          validators: [
            formValidators.factory(this.$options.i18n.groupSelection.validationMessage, (val) => {
              if (this.shouldShowNewGroupForm) {
                return true;
              }
              return Boolean(val);
            }),
          ],
        };
      }

      if (this.shouldShowNewGroupForm) {
        fields[FORM_FIELD_GROUP_NAME] = {
          label: this.$options.i18n.groupName.label,
          inputAttrs: {
            'data-testid': 'subscription-group-name-input',
            placeholder: this.$options.i18n.groupName.placeholder,
          },
          groupAttrs: {
            'data-testid': 'subscription-group-name-group',
          },
          validators: [
            formValidators.required(this.$options.i18n.groupName.validationMessage),
            formValidators.factory(START_RULE.message, (val) => {
              return new RegExp(START_RULE.regex).test(val);
            }),
            formValidators.factory(CONTAINS_RULE.message, (val) => {
              return new RegExp(CONTAINS_RULE.regex).test(val);
            }),
          ],
        };
      }

      return fields;
    },
    selectedGroupId() {
      return this.formValues[FORM_FIELD_GROUP_ID];
    },
    selectedGroup() {
      return this.eligibleGroups.find((group) => group.id === this.selectedGroupId);
    },
    toggleText() {
      if (this.shouldShowNewGroupForm) {
        return this.$options.i18n.groupSelection.newGroupOption;
      }

      if (this.selectedGroup) {
        return this.selectedGroup.name;
      }

      return this.$options.i18n.groupSelection.placeholder;
    },
    groupOptions() {
      return this.eligibleGroups.map(({ id, name, fullPath }) => ({
        text: name,
        value: id,
        secondaryText: `/${fullPath}`,
      }));
    },
    hasEligibleGroups() {
      return this.eligibleGroups.length > 0;
    },
    showAccordion() {
      return this.hasEligibleGroups && !this.shouldShowNewGroupForm;
    },
    planName() {
      switch (this.plansData.code) {
        case 'premium':
          return s__('BillingPlans|Premium');
        case 'ultimate':
          return s__('BillingPlans|Ultimate');
        default:
          return this.plansData.name;
      }
    },
    title() {
      return sprintf(
        s__('SubscriptionGroupsNew|Select a group for your %{planName} subscription'),
        { planName: this.planName },
      );
    },
  },
  watch: {
    [`formValues.${FORM_FIELD_GROUP_ID}`](newValue) {
      if (!newValue) {
        return;
      }

      this.shouldShowNewGroupForm = false;
      this.errorMessage = null;
    },
    [`formValues.${FORM_FIELD_GROUP_NAME}`](groupName) {
      const slug = slugify(groupName || '');

      if (!slug) {
        this.groupSlug = DEFAULT_GROUP_PATH;
        return;
      }

      this.groupSlug = slug;
      this.debouncedOnGroupUpdate(slug);
    },
  },
  created() {
    this.shouldShowNewGroupForm = !this.hasEligibleGroups;
  },
  methods: {
    continueWithSelection() {
      this.isLoading = true;

      if (this.shouldShowNewGroupForm) {
        this.createGroup();
        return;
      }

      this.navigateToPurchaseFlow(this.selectedGroupId);
    },
    async createGroup() {
      const params = { name: this.formValues[FORM_FIELD_GROUP_NAME], path: this.groupSlug };

      try {
        const { data } = await subscriptionsCreateGroup(params);
        if (data?.id) {
          this.navigateToPurchaseFlow(data.id);
        } else {
          throw new Error();
        }
      } catch (error) {
        this.isLoading = false;

        const { errors, message } = error?.response?.data || {};

        if (errors?.name?.length) {
          // We'll add inline form validation for group name in https://gitlab.com/gitlab-org/gitlab/-/issues/468597
          this.errorMessage = sprintf(s__('SubscriptionGroupsNew|Group name %{error}'), {
            error: errors.name[0],
          });
        } else if (errors?.path?.length) {
          this.errorMessage = sprintf(s__('SubscriptionGroupsNew|Group URL %{error}'), {
            error: errors.path[0],
          });
        } else if (message) {
          this.errorMessage = message;
        } else {
          this.errorMessage = this.$options.i18n.errors.problemCreatingGroupError;
        }
      }
    },
    showNewGroupForm() {
      this.formValues[FORM_FIELD_GROUP_ID] = null;

      this.shouldShowNewGroupForm = true;

      this.$refs.collapsibleList.close();
    },
    debouncedOnGroupUpdate: debounce(function debouncedUpdate(slug) {
      this.checkGroupPathAvailability(slug);
    }, DEBOUNCE_TIMEOUT_DURATION),
    async checkGroupPathAvailability(slug) {
      if (this.currentApiRequestController !== null) {
        this.currentApiRequestController.abort();
      }

      this.currentApiRequestController = new AbortController();

      try {
        // parent ID always undefined because we're creating a new group
        const {
          data: { exists, suggests },
        } = await getGroupPathAvailability(slug, undefined, {
          signal: this.currentApiRequestController.signal,
        });

        this.currentApiRequestController = null;

        if (exists && suggests.length) {
          const [suggestedSlug] = suggests;
          this.groupSlug = suggestedSlug;
        }
      } catch (e) {
        // Do nothing as path is not provided by the user and path related errors are handled in group creation request
      }
    },
    navigateToPurchaseFlow(groupId) {
      // We should always have a purchase link available. In the unlikely scenario where
      // we don't, we want to know about it, so let's report the error to Sentry
      if (!this.plansData.purchaseLink?.href) {
        this.reportError(`Missing purchase link for plan ${JSON.stringify(this.plansData)}`);
        return;
      }

      const purchaseLink = `${this.plansData.purchaseLink.href}&gl_namespace_id=${groupId}`;
      visitUrl(purchaseLink);
    },
    reportError(error) {
      Sentry.captureException(error, {
        tags: {
          vue_component: this.$options.name,
        },
      });
    },
  },
  formId: 'subscription-group-form',
  i18n: {
    groupDescription: __(
      'A group represents your organization in GitLab. Groups allow you to manage users and collaborate across multiple projects.',
    ),
    groupSelection: {
      placeholder: __('Select a group'),
      newGroupOption: s__('GroupsNew|Create new group'),
      label: __('Group'),
      description: s__('Checkout|Your subscription will be applied to this group'),
      validationMessage: s__('SubscriptionGroupsNew|Select a group for your subscription.'),
    },
    groupName: {
      label: s__('Groups|Group name'),
      placeholder: __('Enter group name'),
      validationMessage: s__('Groups|Enter a descriptive name for your group.'),
    },
    groupPath: {
      urlHeader: s__('SubscriptionGroupsNew|Your group will be created at:'),
      urlFooter: s__('ProjectsNew|You can always change your URL later'),
    },
    errors: {
      problemCreatingGroupError: __(
        'An error occurred while creating the group. Please try again.',
      ),
    },
    accordion: {
      title: s__(`SubscriptionGroupsNew|Why can't I find my group?`),
      description: s__(
        'SubscriptionGroupsNew|Your group will only be displayed in the list above if:',
      ),
      reasonOne: s__(`SubscriptionGroupsNew|You're assigned the Owner role of the group`),
      reasonTwo: s__('SubscriptionGroupsNew|The group is a top-level group on a Free tier'),
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-justify-center">
    <div class="gl-max-w-88">
      <h2 class="gl-text-center">{{ title }}</h2>
      <div class="gl-m-auto gl-max-w-62">
        <p
          v-if="!hasEligibleGroups"
          data-testid="group-description"
          class="gl-mb-0 gl-mt-7 gl-text-center"
        >
          {{ $options.i18n.groupDescription }}
        </p>
      </div>
      <gl-card class="gl-mx-auto gl-mt-7 gl-max-w-62 gl-p-5">
        <gl-alert v-if="errorMessage" variant="danger" :dismissible="false" class="gl-mb-5">
          <span v-safe-html="errorMessage"></span>
        </gl-alert>
        <gl-form :id="$options.formId">
          <gl-form-fields
            v-model="formValues"
            :form-id="$options.formId"
            :fields="fields"
            @submit="continueWithSelection"
          >
            <template #input(groupId)="{ id, value, input, validation }">
              <gl-collapsible-listbox
                :id="id"
                ref="collapsibleList"
                :selected="value"
                block
                fluid-width
                :items="groupOptions"
                :toggle-text="toggleText"
                category="secondary"
                :variant="validation.state === false ? 'danger' : 'default'"
                @select="input"
              >
                <template #list-item="{ item }">
                  <span class="gl-flex gl-flex-col">
                    <span class="gl-whitespace-nowrap" data-testid="group-name">{{
                      item.text
                    }}</span>
                    <span class="gl-text-subtle" data-testid="group-path">
                      {{ item.secondaryText }}</span
                    >
                  </span>
                </template>
                <template #footer>
                  <div
                    class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-dropdown gl-p-2 gl-pt-0 gl-border-t-solid"
                  >
                    <gl-button
                      category="tertiary"
                      block
                      class="!gl-mt-2 !gl-justify-start"
                      data-testid="show-new-group-form-button"
                      @click="showNewGroupForm"
                      >{{ $options.i18n.groupSelection.newGroupOption }}</gl-button
                    >
                  </div>
                </template>
              </gl-collapsible-listbox>
            </template>
            <template #group(groupId)-label-description>
              <span v-if="hasEligibleGroups" class="gl-text-subtle">{{
                $options.i18n.groupSelection.description
              }}</span>
            </template>
            <template #after(groupId)>
              <gl-accordion v-if="showAccordion" :header-level="3">
                <gl-accordion-item :title="$options.i18n.accordion.title">
                  {{ $options.i18n.accordion.description }}
                  <ul class="gl-mt-4">
                    <li>{{ $options.i18n.accordion.reasonOne }}</li>
                    <li>{{ $options.i18n.accordion.reasonTwo }}</li>
                  </ul>
                </gl-accordion-item>
              </gl-accordion>
            </template>
            <template #group(groupName)-label-description>
              <span v-if="!hasEligibleGroups" class="gl-text-subtle">{{
                $options.i18n.groupSelection.description
              }}</span>
            </template>
            <template #after(groupName)>
              <p class="gl-text-center">{{ $options.i18n.groupPath.urlHeader }}</p>

              <p class="gl-break-words gl-text-center gl-font-monospace" data-testid="group-url">
                {{ rootUrl }}{{ groupSlug }}
              </p>

              <p class="gl-mb-5 gl-text-center gl-text-subtle">
                {{ $options.i18n.groupPath.urlFooter }}
              </p>
            </template>
          </gl-form-fields>
          <gl-button
            class="js-no-auto-disable gl-mt-5 gl-w-full"
            variant="confirm"
            type="submit"
            :loading="isLoading"
            data-testid="continue-button"
            >{{ __('Continue') }}</gl-button
          >
        </gl-form>
      </gl-card>
    </div>
  </div>
</template>
