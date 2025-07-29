<script>
import {
  GlSprintf,
  GlAlert,
  GlButton,
  GlLink,
  GlForm,
  GlLoadingIcon,
  GlTooltip,
  GlModal,
} from '@gitlab/ui';
import produce from 'immer';
import InternalEvents from '~/tracking/internal_events';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { sprintf, __ } from '~/locale';
import { SAVE_ERROR } from 'ee/groups/settings/compliance_frameworks/constants';
import {
  getSubmissionParams,
  initialiseFormData,
} from 'ee/groups/settings/compliance_frameworks/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { ROUTE_NEW_FRAMEWORK_SUCCESS, ROUTE_FRAMEWORKS } from '../../../constants';
import { convertFrameworkIdToGraphQl } from '../../../utils';
import createComplianceFrameworkMutation from '../../../graphql/mutations/create_compliance_framework.mutation.graphql';
import updateComplianceFrameworkMutation from '../../../graphql/mutations/update_compliance_framework.mutation.graphql';
import deleteComplianceFrameworkMutation from '../../../graphql/mutations/delete_compliance_framework.mutation.graphql';
import createRequirementMutation from '../../../graphql/mutations/create_compliance_requirement.mutation.graphql';
import updateRequirementMutation from '../../../graphql/mutations/update_compliance_requirement.mutation.graphql';
import deleteRequirementMutation from '../../../graphql/mutations/delete_compliance_requirement.mutation.graphql';
import getComplianceFrameworkQuery from './graphql/get_compliance_framework.query.graphql';
import DeleteModal from './components/delete_modal.vue';
import BasicInformationSection from './components/basic_information_section.vue';
import RequirementsSection from './components/requirements_section.vue';
import PoliciesSection from './components/policies_section.vue';
import ProjectsSection from './components/projects_section.vue';
import { i18n, requirementEvents } from './constants';

export default {
  components: {
    BasicInformationSection,
    PoliciesSection,
    ProjectsSection,
    RequirementsSection,
    DeleteModal,
    GlAlert,
    GlLink,
    GlSprintf,
    GlButton,
    GlForm,
    GlLoadingIcon,
    GlModal,
    GlTooltip,
  },
  mixins: [InternalEvents.mixin()],
  inject: [
    'pipelineConfigurationFullPathEnabled',
    'groupPath',
    'featureSecurityPoliciesEnabled',
    'pipelineExecutionPolicyPath',
    'migratePipelineToPolicyPath',
  ],
  data() {
    return {
      errorMessage: '',
      formData: initialiseFormData(),
      requirements: [],
      originalName: '',
      showValidation: false,
      isSaving: false,
      isDeleting: false,
      hasMigratedPipeline: false,
      showMigrationPopup: false,
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    namespace: {
      query: getComplianceFrameworkQuery,
      variables() {
        return this.queryVariables;
      },
      result({ data }) {
        const [complianceFramework] = data?.namespace?.complianceFrameworks?.nodes || [];
        if (complianceFramework) {
          const { complianceRequirements, ...rest } = complianceFramework;
          this.formData = { ...rest };
          this.requirements = complianceRequirements?.nodes
            ? [...complianceRequirements.nodes].sort((a, b) => {
                const idA = getIdFromGraphQLId(a.id);
                const idB = getIdFromGraphQLId(b.id);
                return Number(idA) - Number(idB);
              })
            : [];
          this.originalName = complianceFramework.name;
          const policyBlob =
            data.namespace.securityPolicyProject?.repository?.blobs?.nodes?.[0]?.rawBlob;
          if (policyBlob) {
            const id = getIdFromGraphQLId(this.graphqlId);
            const policy = fromYaml({
              manifest: policyBlob,
              type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
              addIds: false,
            });

            this.hasMigratedPipeline = Boolean(
              policy?.policy_scope?.compliance_frameworks?.find((f) => f.id === id) &&
                policy?.metadata?.compliance_pipeline_migration,
            );
          }
        } else {
          this.errorMessage = this.$options.i18n.fetchError;
        }
      },
      error(error) {
        this.errorMessage = this.$options.i18n.fetchError;
        Sentry.captureException(error);
      },
      skip() {
        return this.isNewFramework;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.loading || this.isSaving;
    },
    isNewFramework() {
      return !this.$route.params.id;
    },
    isDefaultFramework() {
      return this.formData.default;
    },
    policiesCount() {
      const {
        scanResultPolicies,
        scanExecutionPolicies,
        pipelineExecutionPolicies,
        vulnerabilityManagementPolicies,
      } = this.formData;

      const policies = [
        scanResultPolicies,
        scanExecutionPolicies,
        pipelineExecutionPolicies,
        vulnerabilityManagementPolicies,
      ];

      return policies.reduce((total, policy) => total + (policy?.nodes?.length || 0), 0);
    },
    hasLinkedPolicies() {
      return this.policiesCount > 0;
    },
    queryVariables() {
      return {
        fullPath: this.groupPath,
        complianceFramework: this.graphqlId,
      };
    },
    deleteBtnDisabled() {
      return this.hasLinkedPolicies || this.isDefaultFramework;
    },
    deleteBtnDisabledTooltip() {
      return this.isDefaultFramework
        ? i18n.deleteButtonDefaultFrameworkDisabledTooltip
        : i18n.deleteButtonLinkedPoliciesDisabledTooltip;
    },
    refetchConfig() {
      return {
        awaitRefetchQueries: true,
        refetchQueries: [
          {
            query: getComplianceFrameworkQuery,
            variables: {
              fullPath: this.groupPath,
            },
          },
        ],
      };
    },
    title() {
      return this.isNewFramework
        ? this.$options.i18n.addFrameworkTitle
        : sprintf(
            this.$options.i18n.editFrameworkTitle,
            { frameworkName: this.originalName },
            false,
          );
    },
    saveButtonText() {
      return this.isNewFramework
        ? this.$options.i18n.addSaveBtnText
        : this.$options.i18n.editSaveBtnText;
    },
    graphqlId() {
      return this.$route.params.id ? convertFrameworkIdToGraphQl(this.$route.params.id) : null;
    },
    shouldRenderPolicySection() {
      return !this.isNewFramework && this.featureSecurityPoliciesEnabled;
    },
    showModal: {
      get() {
        const pipeline = this.hasPipeline;
        return pipeline != null && pipeline.length > 0 && this.showMigrationPopup;
      },
      set() {
        this.showMigrationPopup = false;
        this.$emit('close-modal');
      },
    },
    hasPipeline() {
      return this.formData.pipelineConfigurationFullPath;
    },
  },
  methods: {
    setError(error, userFriendlyText, loadingProp = 'isSaving') {
      this[loadingProp] = false;
      this.errorMessage = userFriendlyText;
      Sentry.captureException(error);
    },
    navigateOutEditView() {
      if (this.isNewFramework) {
        this.$router.back();
      }

      this.$router.push({
        name: ROUTE_FRAMEWORKS,
        query: { id: getIdFromGraphQLId(this.formData.id) },
      });
    },
    async createFramework(params) {
      const { data } = await this.$apollo.mutate({
        mutation: createComplianceFrameworkMutation,
        variables: {
          input: {
            namespacePath: this.groupPath,
            params,
          },
        },
      });
      const framework = data?.createComplianceFramework?.framework;
      const errors = data?.createComplianceFramework?.errors;

      if (errors && errors.length) {
        throw new Error(errors[0]);
      }

      this.trackEvent('create_compliance_framework', {
        property: framework.id,
      });

      return framework.id;
    },
    async updateFramework(params) {
      const { data } = await this.$apollo.mutate({
        mutation: updateComplianceFrameworkMutation,
        variables: {
          input: {
            id: this.graphqlId,
            params,
          },
        },
      });
      const errors = data?.updateComplianceFramework?.errors;

      if (errors && errors.length) {
        throw new Error(errors[0]);
      }
    },
    async onSubmit() {
      this.showValidation = true;
      this.errorMessage = '';

      if (!this.$refs.basicInformation?.isValid) {
        return;
      }

      try {
        this.isSaving = true;
        const params = getSubmissionParams(
          this.formData,
          this.pipelineConfigurationFullPathEnabled,
        );

        if (this.isNewFramework) {
          const frameworkId = await this.createFramework(params);
          await this.createRequirements(frameworkId);
          this.handleMutationSuccess(frameworkId);
        } else {
          await this.updateFramework(params);
          this.interjectModal();
        }
      } catch (error) {
        this.setError(error, SAVE_ERROR);
      } finally {
        this.isSaving = false;
      }
    },
    navigateNewFramework(frameworkId) {
      this.$router.push({
        name: ROUTE_NEW_FRAMEWORK_SUCCESS,
        query: { id: getIdFromGraphQLId(frameworkId) },
      });
    },
    interjectModal() {
      if (!this.hasPipeline) {
        this.handleMutationSuccess(this.formData.id);
      }

      this.showMigrationPopup = true;
    },
    handleMutationSuccess(frameworkId) {
      if (this.isNewFramework) {
        this.navigateNewFramework(frameworkId);
      }
      this.showMigrationPopup = false;
    },
    async createRequirements(frameworkId) {
      const newRequirements = this.requirements.filter((requirement) => !requirement.id);

      if (newRequirements.length === 0) {
        return;
      }

      const createRequirementPromises = newRequirements.map((requirement) =>
        this.createRequirementAtIndex(requirement, frameworkId),
      );

      await Promise.all(createRequirementPromises);
    },
    async createRequirementAtIndex(requirement, frameworkId, index = null) {
      const controls = (
        requirement.stagedControls ||
        requirement.complianceRequirementsControls?.nodes ||
        []
      ).map((control) => ({
        name: control.name,
        controlType: control.controlType || 'internal',
        externalControlName: control.externalControlName || '',
        externalUrl: control.externalUrl || '',
        expression: control.expression || '',
        ...(control.secretToken && { secretToken: control.secretToken }),
      }));

      const { data } = await this.$apollo.mutate({
        mutation: createRequirementMutation,
        variables: {
          input: {
            complianceFrameworkId: frameworkId,
            params: {
              name: requirement.name,
              description: requirement.description,
            },
            controls,
          },
        },
        ...(this.isNewFramework
          ? {}
          : {
              update: (cache, result) => this.updateRequirementCacheOnCreate(cache, result, index),
            }),
      });
      const errors = data?.createComplianceRequirement?.errors;

      if (errors && errors.length) {
        throw new Error(errors[0]);
      }
    },
    updateRequirementCacheOnCreate(cache, { data: { createComplianceRequirement } }, index = null) {
      const newRequirement = createComplianceRequirement?.requirement;
      const errors = createComplianceRequirement?.errors;

      if (errors && errors.length) {
        return;
      }
      const sourceData = cache.readQuery({
        query: getComplianceFrameworkQuery,
        variables: this.queryVariables,
      });

      const updatedData = produce(sourceData, (draft) => {
        const framework = draft.namespace.complianceFrameworks.nodes.find(
          (f) => f.id === this.graphqlId,
        );
        if (framework) {
          if (index !== null) {
            framework.complianceRequirements.nodes.splice(index, 0, newRequirement);
          } else {
            framework.complianceRequirements.nodes.push(newRequirement);
          }
        }
      });

      cache.writeQuery({
        query: getComplianceFrameworkQuery,
        variables: this.queryVariables,
        data: updatedData,
      });
    },
    async updateRequirement(requirement) {
      const controls = (requirement.stagedControls || []).map((control) => ({
        name: control.name,
        controlType: control.controlType || 'internal',
        externalControlName: control.externalControlName || '',
        externalUrl: control.externalUrl || '',
        expression: control.expression || '',
        ...(control.secretToken && { secretToken: control.secretToken }),
      }));

      const { data } = await this.$apollo.mutate({
        mutation: updateRequirementMutation,
        variables: {
          input: {
            id: requirement.id,
            params: {
              name: requirement.name,
              description: requirement.description,
            },
            controls,
          },
        },
        update: (cache, result) => this.updateRequirementCacheOnUpdate(cache, result),
      });

      const errors = data?.updateComplianceRequirement?.errors;

      if (errors && errors.length) {
        throw new Error(errors[0]);
      }
    },
    updateRequirementCacheOnUpdate(cache, { data: { updateComplianceRequirement } }) {
      const updatedRequirement = updateComplianceRequirement?.requirement;
      const errors = updateComplianceRequirement?.errors;

      if (errors && errors.length) {
        return;
      }

      const sourceData = cache.readQuery({
        query: getComplianceFrameworkQuery,
        variables: this.queryVariables,
      });

      const updatedData = produce(sourceData, (draft) => {
        const framework = draft.namespace.complianceFrameworks.nodes.find(
          (f) => f.id === this.graphqlId,
        );
        if (framework) {
          const index = framework.complianceRequirements.nodes.findIndex(
            (req) => req.id === updatedRequirement.id,
          );
          if (index !== -1) {
            framework.complianceRequirements.nodes[index] = updatedRequirement;
          }
        }
      });

      cache.writeQuery({
        query: getComplianceFrameworkQuery,
        variables: this.queryVariables,
        data: updatedData,
      });
    },
    async handleCreateRequirement({ requirement, index }) {
      if (this.isNewFramework) {
        if (index !== null) {
          this.requirements.splice(index, 0, requirement);
        } else {
          this.requirements.push(requirement);
        }
      } else {
        try {
          await this.createRequirementAtIndex(requirement, this.graphqlId, index);
        } catch (error) {
          this.setError(error, error);
        }
      }
    },
    async handleUpdateRequirement({ requirement, index }) {
      if (this.isNewFramework) {
        if (index !== null) {
          this.requirements.splice(index, 1, requirement);
        }
      } else {
        try {
          if (requirement?.id) {
            await this.updateRequirement(requirement);
            if (index !== null) {
              const updatedRequirement = {
                ...requirement,
                complianceRequirementsControls: {
                  nodes:
                    requirement.stagedControls?.map((control) => ({
                      id: control.id,
                      name: control.name,
                      controlType: control.controlType,
                      expression: control.expression,
                      __typename: 'ComplianceRequirementControl',
                    })) || [],
                  __typename: 'ComplianceRequirementControlConnection',
                },
              };
              this.requirements.splice(index, 1, updatedRequirement);
            }
          }
        } catch (error) {
          this.setError(error, error);
        }
      }
    },
    async handleDeleteRequirement(index) {
      const requirementToDelete = this.requirements[index];
      if (!requirementToDelete) {
        return;
      }

      if (this.isNewFramework) {
        this.requirements.splice(index, 1);
        this.showUndoDeleteRequirementToast(requirementToDelete, index);
      } else if (requirementToDelete.id) {
        try {
          await this.deleteRequirement(requirementToDelete.id);
          this.showUndoDeleteRequirementToast(requirementToDelete, index);
        } catch (error) {
          this.setError(error, error);
        }
      }
    },
    showUndoDeleteRequirementToast(requirementToDelete, index) {
      const { id, ...requirement } = requirementToDelete;
      this.$toast.show(this.$options.i18n.requirementRemovedMessage, {
        action: {
          text: __('Undo'),
          onClick: (_, toast) => {
            this.handleCreateRequirement({ requirement, index });
            toast.hide();
          },
        },
      });
    },
    async deleteRequirement(requirementId) {
      const { data } = await this.$apollo.mutate({
        mutation: deleteRequirementMutation,
        variables: {
          input: {
            id: requirementId,
          },
        },
        update: (cache, result) =>
          this.updateRequirementCacheOnDelete(cache, result, requirementId),
      });

      const errors = data?.deleteComplianceRequirement?.errors;
      if (errors && errors.length) {
        throw new Error(errors[0]);
      }
    },

    updateRequirementCacheOnDelete(cache, { data: { deleteComplianceRequirement } }, id) {
      const errors = deleteComplianceRequirement?.errors;
      if (errors && errors.length) {
        return;
      }

      const sourceData = cache.readQuery({
        query: getComplianceFrameworkQuery,
        variables: this.queryVariables,
      });

      const updatedData = produce(sourceData, (draft) => {
        const framework = draft.namespace.complianceFrameworks.nodes.find(
          (f) => f.id === this.graphqlId,
        );
        if (framework) {
          framework.complianceRequirements.nodes = framework.complianceRequirements.nodes.filter(
            (req) => req.id !== id,
          );
        }
      });

      cache.writeQuery({
        query: getComplianceFrameworkQuery,
        variables: this.queryVariables,
        data: updatedData,
      });
    },
    async deleteFramework() {
      this.isDeleting = true;

      try {
        const {
          data: { destroyComplianceFramework },
        } = await this.$apollo.mutate({
          mutation: deleteComplianceFrameworkMutation,
          variables: {
            input: {
              id: this.graphqlId,
            },
          },
          ...this.refetchConfig,
        });

        const [error] = destroyComplianceFramework.errors;

        if (error) {
          throw error;
        }
        this.$router.back();
      } catch (error) {
        this.setError(new Error(error), error, 'isDeleting');
      }
    },
    onDelete() {
      this.$refs.deleteModal.show();
    },
    updateProjects({ addProjects, removeProjects }) {
      this.formData.projects = {
        addProjects,
        removeProjects,
      };
    },
  },
  modalId: 'warn-when-using-pipeline-modal',
  i18n,
  requirementEvents,
};
</script>

<template>
  <div class="gl-mt-7">
    <gl-alert v-if="errorMessage" class="gl-mb-7" variant="danger" :dismissible="false">
      {{ errorMessage }}
    </gl-alert>

    <gl-modal
      ref="modal"
      v-model="showModal"
      data-testid="pipeline-migration-popup"
      :modal-id="$options.modalId"
      :title="$options.i18n.deprecationWarning.title"
      hide-footer
    >
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.deprecationWarning.message">
          <template #link="{ content }">
            <gl-link :href="pipelineExecutionPolicyPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <p>
        <gl-sprintf :message="$options.i18n.deprecationWarning.details">
          <template #link="{ content }">
            <gl-link :href="migratePipelineToPolicyPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </gl-modal>
    <gl-loading-icon v-if="isLoading" size="lg" />

    <template v-else>
      <h2 class="gl-heading-2 gl-mb-7">{{ title }}</h2>
      <gl-form @submit.prevent="onSubmit">
        <basic-information-section
          v-if="formData"
          ref="basicInformation"
          v-model="formData"
          :is-expanded="isNewFramework"
          :has-migrated-pipeline="hasMigratedPipeline"
          :show-validation="showValidation"
        />

        <requirements-section
          :requirements="requirements"
          :is-new-framework="isNewFramework"
          @[$options.requirementEvents.create]="handleCreateRequirement"
          @[$options.requirementEvents.update]="handleUpdateRequirement"
          @[$options.requirementEvents.delete]="handleDeleteRequirement"
        />

        <policies-section
          v-if="shouldRenderPolicySection"
          :count="policiesCount"
          :is-expanded="isNewFramework"
          :full-path="groupPath"
          :graphql-id="graphqlId"
        />

        <projects-section
          :compliance-framework="formData"
          :group-path="groupPath"
          @update:projects="updateProjects"
        />

        <div class="gl-flex gl-gap-3 gl-px-5 gl-pt-6">
          <gl-button
            type="submit"
            variant="confirm"
            class="js-no-auto-disable"
            data-testid="submit-btn"
          >
            {{ saveButtonText }}
          </gl-button>
          <gl-button data-testid="cancel-btn" @click="navigateOutEditView">
            {{ __('Cancel') }}
          </gl-button>
          <template v-if="graphqlId">
            <gl-tooltip
              v-if="deleteBtnDisabled"
              :target="() => $refs.deleteBtn"
              :title="deleteBtnDisabledTooltip"
            />
            <div ref="deleteBtn" class="gl-ml-auto">
              <gl-button
                variant="danger"
                data-testid="delete-btn"
                :loading="isDeleting"
                :disabled="deleteBtnDisabled"
                @click="onDelete"
              >
                {{ $options.i18n.deleteButtonText }}
              </gl-button>
            </div>
          </template>
        </div>
      </gl-form>
    </template>

    <delete-modal
      v-if="graphqlId"
      ref="deleteModal"
      :name="originalName"
      @delete="deleteFramework"
    />
  </div>
</template>
