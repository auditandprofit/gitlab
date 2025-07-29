<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { sortBy } from 'lodash';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import { DUO_MAIN_FEATURES } from 'ee/ai/shared/feature_settings/constants';

import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import FeatureSettingsTable from './feature_settings_table.vue';
import BetaFeaturesAlert from './beta_features_alert.vue';

export default {
  name: 'FeatureSettings',
  components: {
    FeatureSettingsTable,
    FeatureSettingsBlock,
    BetaFeaturesAlert,
    GlLink,
    GlSprintf,
  },
  inject: ['betaModelsEnabled', 'duoConfigurationSettingsPath'],
  codeSuggestionsHelpPage: helpPagePath('user/project/repository/code_suggestions/_index'),
  duoChatHelpPage: helpPagePath('user/gitlab_duo_chat/_index'),
  mergeRequestsHelpPage: helpPagePath('user/project/merge_requests/duo_in_merge_requests'),
  issuesHelpPage: helpPagePath('user/discussions/_index', {
    anchor: 'summarize-issue-discussions-with-duo-chat',
  }),
  otherGitLabDuoHelpPage: helpPagePath('user/get_started/getting_started_gitlab_duo', {
    anchor: 'step-3-try-other-gitlab-duo-features',
  }),
  data() {
    return {
      aiFeatureSettings: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
    sections() {
      const otherGitLabDuoFeatures = this.getSubFeatures(
        DUO_MAIN_FEATURES.OTHER_GITLAB_DUO_FEATURES,
      );
      const mergeRequestFeatures = this.getSubFeatures(DUO_MAIN_FEATURES.MERGE_REQUESTS);
      const issuesFeatures = this.getSubFeatures(DUO_MAIN_FEATURES.ISSUES);

      return [
        {
          id: 'code-suggestions',
          title: s__('AdminAIPoweredFeatures|Code Suggestions'),
          description: s__(
            'AdminAIPoweredFeatures|Assists developers by generating and completing code in real-time. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.codeSuggestionsHelpPage,
          features: this.getSubFeatures(DUO_MAIN_FEATURES.CODE_SUGGESTIONS),
          hasBetaFeatures: false,
          show: true,
        },
        {
          id: 'duo-chat',
          title: s__('AdminAIPoweredFeatures|GitLab Duo Chat'),
          description: s__(
            'AdminAIPoweredFeatures|An AI assistant that helps users accelerate software development using real-time conversational AI. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.duoChatHelpPage,
          features: this.getSubFeatures(DUO_MAIN_FEATURES.DUO_CHAT),
          hasBetaFeatures: true,
          show: true,
        },
        {
          id: 'duo-merge-requests',
          title: s__('AdminAIPoweredFeatures|GitLab Duo for merge requests'),
          description: s__(
            'AdminAIPoweredFeatures|AI-native features that help users accomplish tasks during the lifecycle of a merge request. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.mergeRequestsHelpPage,
          features: mergeRequestFeatures,
          hasBetaFeatures: false,
          show: mergeRequestFeatures.length,
        },
        {
          id: 'duo-issues',
          title: s__('AdminAIPoweredFeatures|GitLab Duo for issues'),
          description: s__(
            'AdminAIPoweredFeatures|An AI-native feature that generates a summary of discussions on an issue. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.issuesHelpPage,
          features: issuesFeatures,
          hasBetaFeatures: false,
          show: issuesFeatures.length,
        },

        {
          id: 'other-duo-features',
          title: s__('AdminAIPoweredFeatures|Other GitLab Duo features'),
          description: s__(
            'AdminAIPoweredFeatures|AI-native features that support users outside of Chat or Code Suggestions. %{linkStart}Learn more.%{linkEnd}',
          ),
          link: this.$options.otherGitLabDuoHelpPage,
          features: otherGitLabDuoFeatures,
          hasBetaFeatures: true,
          show: otherGitLabDuoFeatures.length,
        },
      ];
    },
  },
  apollo: {
    aiFeatureSettings: {
      query: getAiFeatureSettingsQuery,
      update(data) {
        return data.aiFeatureSettings?.nodes || [];
      },
      error(error) {
        createAlert({
          message: s__(
            'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
          ),
          error,
          captureError: true,
        });
      },
    },
  },
  methods: {
    getSubFeatures(mainFeature) {
      const displayOrder = {
        GA: 1,
        BETA: 2,
        EXPERIMENT: 3,
      };

      const subFeatures = this.aiFeatureSettings.filter(
        (setting) => setting.mainFeature === mainFeature,
      );
      // sort rows by releaseState
      return sortBy(subFeatures, (subFeature) => displayOrder[subFeature.releaseState]);
    },
  },
};
</script>
<template>
  <div>
    <div v-for="section in sections" :key="section.id">
      <feature-settings-block v-if="section.show" :id="section.id" :title="section.title">
        <template #description>
          <gl-sprintf :message="section.description">
            <template #link="{ content }">
              <gl-link :href="section.link" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
        <template #content>
          <div>
            <beta-features-alert
              v-if="section.hasBetaFeatures && !betaModelsEnabled"
              :duo-configuration-settings-path="duoConfigurationSettingsPath"
            />
            <feature-settings-table
              :data-testid="`${section.id}-table`"
              :feature-settings="section.features"
              :is-loading="isLoading"
            />
          </div>
        </template>
      </feature-settings-block>
    </div>
  </div>
</template>
