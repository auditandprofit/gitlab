<script>
import { GlCard, GlButton, GlIcon } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';

export default {
  name: 'GetFamiliar',
  components: {
    GlCard,
    GlButton,
    GlIcon,
  },
  mixins: [InternalEvents.mixin()],
  methods: {
    trackTryWalkthroughClick() {
      this.trackEvent('click_duo_try_walkthrough_in_get_started');
    },
  },
};
</script>

<template>
  <div>
    <header>
      <h2 class="gl-text-size-h2">{{ s__('LearnGitLab|Get familiar with GitLab Duo') }}</h2>
      <p class="gl-mb-3 gl-text-subtle">
        {{
          s__('LearnGitLab|Explore these resources to learn essential features and best practices.')
        }}
      </p>
    </header>

    <gl-card
      header-class="gl-font-bold"
      footer-class="gl-py-0 gl-bg-transparent gl-border-t-0"
      data-testid="duo-code-suggestions-card"
    >
      <template #header>
        {{ s__('LearnGitLab|GitLab Duo Code Suggestions') }}
      </template>

      <template #default>
        <div class="gl-px-5 gl-py-4">
          <ul class="gl-mb-0 gl-pl-4" :aria-label="__(`GitLab Duo code features`)">
            <li class="gl-mb-3">
              <strong>{{ s__('LearnGitLab|Code completion:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Suggests completions to the current line you are typing. Use it to complete one or a few lines of code.',
                )
              }}
            </li>
            <li class="gl-mb-3">
              <strong>{{ s__('LearnGitLab|Code generation:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Generates code based on a natural language code comment block. Write a comment, then press Enter to generate code based on the context of your comment, and the rest of your code.',
                )
              }}
            </li>
            <li class="gl-mb-3">
              <strong>{{ s__('LearnGitLab|Context-aware suggestions:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Uses open files in your IDE, content before and after the cursor, filename, and extension type to provide relevant suggestions.',
                )
              }}
            </li>
            <li>
              <strong>{{ s__('LearnGitLab|Support for multiple languages:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Works with various programming languages supported by your development environment.',
                )
              }}
            </li>
          </ul>
        </div>
      </template>

      <template #footer>
        <div class="gl-display-flex gl-justify-content-start gl-pb-6 gl-pt-1">
          <gl-button
            data-testid="walkthrough-link"
            category="tertiary"
            target="_blank"
            href="https://gitlab.navattic.com/gitlab-with-duo-get-started-page"
            :aria-label="s__('LearnGitLab|Try the walkthrough in a new tab')"
            @click="trackTryWalkthroughClick"
          >
            {{ s__('LearnGitLab|Try walkthrough') }}
            <gl-icon name="external-link" class="gl-ml-2" />
          </gl-button>
        </div>
      </template>
    </gl-card>
  </div>
</template>
