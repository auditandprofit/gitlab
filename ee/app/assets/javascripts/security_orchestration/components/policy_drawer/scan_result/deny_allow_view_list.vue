<script>
import { GlAccordion, GlAccordionItem, GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';

const TH_CSS_CLASSES = '!gl-pl-0 !gl-text-sm !gl-border-t-0';
const TD_CSS_CLASSES = '!gl-pl-0 !gl-border-none !gl-pb-3 !gl-text-sm';

export default {
  i18n: {
    allowListHeader: s__('SecurityOrchestration|Allowlist details'),
    denyListHeader: s__('SecurityOrchestration|Denylist details'),
    denyTableHeader: s__('SecurityOrchestration|Denied licenses'),
    allowTableHeader: s__('SecurityOrchestration|Allowed licenses'),
    exceptionsHeader: s__('ScanResultPolicy|Exceptions that require approval'),
    exceptionsDenyHeader: s__('ScanResultPolicy|Exceptions that do not require approval'),
    noExceptionsText: s__('SecurityOrchestration|No exceptions'),
  },
  name: 'DenyAllowViewList',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlTableLite,
  },
  props: {
    isDenied: {
      type: Boolean,
      required: false,
      default: false,
    },
    items: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    accordionTitle() {
      return this.isDenied ? this.$options.i18n.denyListHeader : this.$options.i18n.allowListHeader;
    },
    tableFields() {
      return [
        {
          key: 'licenses',
          label: this.isDenied
            ? this.$options.i18n.denyTableHeader
            : this.$options.i18n.allowTableHeader,
          thAttr: { 'data-testid': 'list-type-th' },
          thClass: TH_CSS_CLASSES,
          tdClass: TD_CSS_CLASSES,
        },
        {
          key: 'exceptions',
          label: this.isDenied
            ? this.$options.i18n.exceptionsDenyHeader
            : this.$options.i18n.exceptionsHeader,
          thAttr: { 'data-testid': 'exception-th' },
          thClass: TH_CSS_CLASSES,
          tdClass: TD_CSS_CLASSES,
        },
      ];
    },
  },
  methods: {
    mapExceptionPackagesToString(exceptions = []) {
      if (exceptions.length === 0) {
        return this.$options.i18n.noExceptionsText;
      }

      return exceptions.join(' ') || '';
    },
    getLicenseText(item) {
      return item?.license?.text || '';
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3">
    <gl-accordion-item :title="accordionTitle">
      <gl-table-lite :fields="tableFields" :items="items" table-class="gl-border-b" stacked="md">
        <template #cell(licenses)="{ item = {} }">
          {{ getLicenseText(item) }}
        </template>
        <template #cell(exceptions)="{ item = {} }">
          {{ mapExceptionPackagesToString(item.exceptions) }}
        </template>
      </gl-table-lite>
    </gl-accordion-item>
  </gl-accordion>
</template>
