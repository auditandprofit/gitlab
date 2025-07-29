<script>
import { InternalEvents } from '~/tracking';
import getSecurityAttributesQuery from '../../graphql/client/security_attributes.query.graphql';
import CategoryList from './category_list.vue';
import CategoryForm from './category_form.vue';
import AttributeDrawer from './attribute_drawer.vue';
import { defaultCategory } from './constants';

export default {
  components: {
    CategoryList,
    CategoryForm,
    AttributeDrawer,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['groupFullPath'],
  data() {
    return {
      group: {
        securityAttributeCategories: { nodes: [] },
        securityAttributes: { nodes: [] },
      },
      selectedCategory: null,
    };
  },
  apollo: {
    group: {
      query: getSecurityAttributesQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
          categoryId: this.selectedCategory?.id,
        };
      },
      result({ data }) {
        if (!this.selectedCategory && data.group.securityAttributeCategories.nodes.length) {
          this.selectCategory(data.group.securityAttributeCategories.nodes[0]);
        }
      },
    },
  },
  mounted() {
    this.trackEvent('view_group_security_attributes');
  },
  methods: {
    selectCategory(category) {
      this.selectedCategory = {
        ...defaultCategory,
        ...category,
      };
    },
    openDrawer(mode, item) {
      this.$refs.attributeDrawer.open(mode, item);
    },
    editAttribute(attribute) {
      this.openDrawer('edit', attribute);
    },
    addAttribute() {
      this.openDrawer('add');
    },
    onSubmit(item) {
      // eslint-disable-next-line no-console
      console.log(item);
    },
    onDelete(item) {
      // eslint-disable-next-line no-console
      console.log(item);
    },
  },
};
</script>
<template>
  <div class="gl-border-t gl-flex">
    <div class="gl-border-r gl-w-1/4 gl-min-w-20 gl-p-5">
      <category-list
        :security-attribute-categories="group.securityAttributeCategories.nodes"
        :selected-category="selectedCategory"
        @selectCategory="selectCategory"
      />
    </div>
    <div class="gl-w-3/4">
      <category-form
        :security-attributes="group.securityAttributes.nodes"
        :category="selectedCategory"
        @addAttribute="addAttribute"
        @editAttribute="editAttribute"
      />
      <attribute-drawer ref="attributeDrawer" @saved="onSubmit" @delete="onDelete" />
    </div>
  </div>
</template>
