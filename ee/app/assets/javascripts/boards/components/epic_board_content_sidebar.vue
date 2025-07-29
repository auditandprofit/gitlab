<script>
import { GlDrawer } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { union } from 'lodash';
import activeBoardItemQuery from 'ee_else_ce/boards/graphql/client/active_board_item.query.graphql';
import setActiveBoardItemMutation from 'ee_else_ce/boards/graphql/client/set_active_board_item.mutation.graphql';
import SidebarAncestorsWidget from 'ee_component/sidebar/components/ancestors_tree/sidebar_ancestors_widget.vue';
import { s__ } from '~/locale';
import { ListType } from '~/boards/constants';
import BoardSidebarTitle from '~/boards/components/sidebar/board_sidebar_title.vue';
import { setError, identifyAffectedLists } from '~/boards/graphql/cache_updates';
import SidebarConfidentialityWidget from '~/sidebar/components/confidential/sidebar_confidentiality_widget.vue';
import SidebarParticipantsWidget from '~/sidebar/components/participants/sidebar_participants_widget.vue';
import SidebarSubscriptionsWidget from '~/sidebar/components/subscriptions/sidebar_subscriptions_widget.vue';
import SidebarTodoWidget from '~/sidebar/components/todo_toggle/sidebar_todo_widget.vue';
import SidebarLabelsWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  ListType,
  components: {
    BoardSidebarTitle,
    GlDrawer,
    MountingPortal,
    SidebarAncestorsWidget,
    SidebarConfidentialityWidget,
    SidebarLabelsWidget,
    SidebarParticipantsWidget,
    SidebarSubscriptionsWidget,
    SidebarTodoWidget,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['canUpdate', 'labelsFilterBasePath', 'issuableType', 'allowSubEpics'],
  inheritAttrs: false,
  props: {
    backlogListId: {
      type: String,
      required: true,
    },
    closedListId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      affectedListTypes: [],
      updatedAttributeIds: [],
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    activeBoardCard: {
      query: activeBoardItemQuery,
      variables: {
        isIssue: false,
      },
      update(data) {
        if (!data.activeBoardItem?.id) {
          return { id: '', iid: '' };
        }
        return data.activeBoardItem;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while selecting the card. Please try again.'),
        });
      },
    },
  },
  computed: {
    isSidebarOpen() {
      return Boolean(this.activeBoardCard?.id);
    },
    fullPath() {
      return this.activeBoardCard?.referencePath?.split('&')[0] || '';
    },
    apolloClient() {
      return this.$apollo.provider.defaultClient;
    },
  },
  methods: {
    async handleClose() {
      const item = this.activeBoardCard;

      await this.$apollo.mutate({
        mutation: setActiveBoardItemMutation,
        variables: {
          boardItem: null,
          listId: null,
        },
      });
      if (item.listId !== this.closedListId) {
        await this.refetchAffectedLists(item);
      }
      this.affectedListTypes = [];
      this.updatedAttributeIds = [];
    },
    updateAffectedLists({ listType, attribute }) {
      if (!this.affectedListTypes.includes(listType)) {
        this.affectedListTypes.push(listType);
      }
      this.updatedAttributeIds = union(
        this.updatedAttributeIds,
        attribute.map(({ id }) => id),
      );
    },
    refetchAffectedLists(item) {
      if (!this.affectedListTypes.length) {
        return;
      }

      const affectedLists = identifyAffectedLists({
        client: this.apolloClient,
        item,
        issuableType: this.issuableType,
        affectedListTypes: this.affectedListTypes,
        updatedAttributeIds: this.updatedAttributeIds,
      });

      if (this.backlogListId && !affectedLists.includes(this.backlogListId)) {
        affectedLists.push(this.backlogListId);
      }

      this.apolloClient.refetchQueries({
        updateCache(cache) {
          affectedLists.forEach((listId) => {
            cache.evict({
              id: cache.identify({
                __typename: 'EpicList',
                id: listId,
              }),
              fieldName: 'epics',
            });
            cache.evict({
              id: cache.identify({
                __typename: 'EpicList',
                id: listId,
              }),
              fieldName: 'metadata',
            });
          });
        },
      });
    },
  },
};
</script>

<template>
  <mounting-portal mount-to="#js-right-sidebar-portal" name="epic-board-sidebar" append>
    <gl-drawer
      v-bind="$attrs"
      class="boards-sidebar"
      :open="isSidebarOpen"
      variant="sidebar"
      @close="handleClose"
    >
      <template #title>
        <h2 class="gl-my-0 gl-text-size-h2 gl-leading-24">{{ __('Epic details') }}</h2>
      </template>
      <template #header>
        <sidebar-todo-widget
          class="gl-mt-3"
          :issuable-id="activeBoardCard.id"
          :issuable-iid="activeBoardCard.iid"
          :full-path="fullPath"
          :issuable-type="issuableType"
        />
      </template>
      <template #default>
        <board-sidebar-title :active-item="activeBoardCard" data-testid="sidebar-title" />
        <sidebar-labels-widget
          class="block labels"
          data-testid="sidebar-labels"
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          :allow-label-remove="canUpdate"
          :allow-multiselect="true"
          :labels-filter-base-path="labelsFilterBasePath"
          :attr-workspace-path="fullPath"
          workspace-type="group"
          :issuable-type="issuableType"
          label-create-type="group"
          @updateSelectedLabels="
            updateAffectedLists({ listType: $options.ListType.label, attribute: $event.labels })
          "
        >
          {{ __('None') }}
        </sidebar-labels-widget>

        <sidebar-confidentiality-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          :issuable-type="issuableType"
        />
        <sidebar-ancestors-widget
          v-if="allowSubEpics"
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          issuable-type="epic"
        />
        <sidebar-participants-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          issuable-type="epic"
        />
        <sidebar-subscriptions-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          :issuable-type="issuableType"
          :show-in-dropdown="false"
        />
      </template>
    </gl-drawer>
  </mounting-portal>
</template>
