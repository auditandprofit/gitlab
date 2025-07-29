<script>
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import ModelSelectDropdown from '../shared/feature_settings/model_select_dropdown.vue';
import updateAiNamespaceFeatureSettingsMutation from './graphql/update_ai_namespace_feature_settings.mutation.graphql';
import getAiNamespaceFeatureSettingsQuery from './graphql/get_ai_namepace_feature_settings.query.graphql';

export default {
  name: 'ModelSelector',
  components: {
    ModelSelectDropdown,
  },
  inject: ['groupId'],
  props: {
    aiFeatureSetting: {
      type: Object,
      required: true,
    },
    batchUpdateIsSaving: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isSaving: false,
    };
  },
  computed: {
    selectedModel() {
      return this.aiFeatureSetting.selectedModel?.ref || '';
    },
    defaultModelOption() {
      const text = sprintf(s__('AdminAIPoweredFeatures|GitLab Default %{defaultModel}'), {
        defaultModel: `(${this.aiFeatureSetting.defaultModel?.name})` || '',
      });

      return { value: '', text };
    },
    listItems() {
      const modelOptions = this.aiFeatureSetting.selectableModels.map(({ ref, name }) => ({
        value: ref,
        text: name,
      }));

      return [...modelOptions, this.defaultModelOption];
    },
    selectedOption() {
      return this.listItems.find(({ value }) => value === this.selectedModel);
    },
  },
  methods: {
    async onSelect(option) {
      this.isSaving = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiNamespaceFeatureSettingsMutation,
          variables: {
            input: {
              features: [this.aiFeatureSetting.feature.toUpperCase()],
              groupId: this.groupId,
              offeredModelRef: option,
            },
          },
          refetchQueries: [
            { query: getAiNamespaceFeatureSettingsQuery, variables: { groupId: this.groupId } },
          ],
        });

        if (data) {
          const { errors } = data.aiModelSelectionNamespaceUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.$toast.show(this.successMessage(this.aiFeatureSetting));
        }
      } catch (error) {
        createAlert({
          message: this.errorMessage(error),
          error,
          captureError: true,
        });
      } finally {
        this.isSaving = false;
      }
    },
    successMessage(aiFeatureSetting) {
      return sprintf(s__('ModelSelection|Successfully updated %{mainFeature} / %{title}'), {
        mainFeature: aiFeatureSetting.mainFeature,
        title: aiFeatureSetting.title,
      });
    },
    errorMessage(error) {
      return (
        error.message ||
        s__(
          'ModelSelection|An error occurred while updating the feature setting. Please try again.',
        )
      );
    },
  },
};
</script>
<template>
  <model-select-dropdown
    :selected-option="selectedOption"
    :items="listItems"
    :is-loading="isSaving || batchUpdateIsSaving"
    @select="onSelect"
  />
</template>
