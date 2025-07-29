<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogAgentRunForm from '../components/ai_catalog_agent_run_form.vue';

export default {
  name: 'AiCatalogAgentsRun',
  components: {
    PageHeading,
    AiCatalogAgentRunForm,
  },
  props: {
    aiCatalogAgent: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isSubmitting: false,
    };
  },
  computed: {
    pageTitle() {
      return `${s__('AICatalog|Run agent')}: ${this.aiCatalogAgent.name}`;
    },
  },
  methods: {
    async onSubmit({ userPrompt }) {
      this.isSubmitting = true;

      try {
        this.$toast.show(userPrompt);
      } catch (error) {
        this.$toast.show(s__('AICatalog|Failed to run agent.'));
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="pageTitle">
      <template #description>
        <p>
          {{ s__('AICatalog|Test run agents to see how they respond.') }}
        </p>
      </template>
    </page-heading>

    <ai-catalog-agent-run-form
      :is-submitting="isSubmitting"
      :ai-catalog-agent="aiCatalogAgent"
      @submit="onSubmit"
    />
  </div>
</template>
