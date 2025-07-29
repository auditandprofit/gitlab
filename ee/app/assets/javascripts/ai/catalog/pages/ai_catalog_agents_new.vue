<script>
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createAiCatalogAgent from '../graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

export default {
  name: 'AiCatalogAgentsNew',
  components: {
    AiCatalogAgentForm,
    PageHeading,
  },
  data() {
    return {
      errorMessages: [],
      isSubmitting: false,
    };
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogAgent,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors } = data.aiCatalogAgentCreate;
          if (errors.length > 0) {
            this.errorMessages = errors;
            return;
          }

          const newAgentId = getIdFromGraphQLId(data.aiCatalogAgentCreate.item.id);
          this.$toast.show(s__('AICatalog|Agent created successfully.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_ROUTE,
            query: { [AI_CATALOG_SHOW_QUERY_PARAM]: newAgentId },
          });
        }
      } catch (error) {
        this.errorMessages = [s__('AICatalog|The agent could not be added. Please try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    resetErrorMessages() {
      this.errorMessages = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|Create new agent')" />

    <ai-catalog-agent-form
      mode="create"
      :is-loading="isSubmitting"
      :error-messages="errorMessages"
      @dismiss-error="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
