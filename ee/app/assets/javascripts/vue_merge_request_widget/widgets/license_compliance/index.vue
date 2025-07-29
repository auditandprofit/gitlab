<script>
import { isEmpty } from 'lodash';
import { sprintf, s__, n__ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import { LICENSE_APPROVAL_STATUS } from 'ee/vue_shared/license_compliance/constants';
import MrWidget from '~/vue_merge_request_widget/components/widget/widget.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import { parseDependencies } from './utils';

const APPROVAL_STATUS_TO_ICON = {
  allowed: EXTENSION_ICONS.success,
  denied: EXTENSION_ICONS.failed,
  unclassified: EXTENSION_ICONS.notice,
};

export default {
  name: 'WidgetLicenseCompliance',
  path: 'license-compliance',
  i18n: {
    label: s__('ciReport|License Compliance'),
    loading: s__('ciReport|License Compliance test metrics results are being parsed'),
    error: s__('ciReport|License Compliance failed loading results'),
  },
  components: {
    MrWidget,
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      licenseComplianceData: {
        collapsed: null,
        expanded: null,
      },
    };
  },
  computed: {
    newLicenses() {
      return this.licenseComplianceData.collapsed?.new_licenses || 0;
    },
    existingLicenses() {
      return this.licenseComplianceData.collapsed?.existing_licenses || 0;
    },
    licenseReportCount() {
      return this.newLicenses;
    },
    hasReportItems() {
      return this.licenseReportCount > 0;
    },
    hasBaseReportLicenses() {
      return this.existingLicenses > 0;
    },
    hasDeniedLicense() {
      return this.licenseComplianceData.collapsed?.has_denied_licenses;
    },
    shouldCollapse() {
      return this.hasReportItems;
    },
    tertiaryButtons() {
      return [
        {
          text: s__('ciReport|Full report'),
          href: this.mr.licenseCompliance.license_scanning.full_report_path,
          trackFullReportClicked: true,
          target: '_self',
        },
      ];
    },
    hasApprovalRequired() {
      return Boolean(this.licenseComplianceData.collapsed?.approval_required);
    },
    summaryTextWithReportItems() {
      if (this.hasApprovalRequired && this.hasDeniedLicense) {
        if (this.hasBaseReportLicenses) {
          return n__(
            'LicenseCompliance|License Compliance detected %d new license and policy violation; approval required',
            'LicenseCompliance|License Compliance detected %d new licenses and policy violations; approval required',
            this.licenseReportCount,
          );
        }
        return n__(
          'LicenseCompliance|License Compliance detected %d license and policy violation for the source branch only; approval required',
          'LicenseCompliance|License Compliance detected %d licenses and policy violations for the source branch only; approval required',
          this.licenseReportCount,
        );
      }

      if (this.hasBaseReportLicenses && !this.hasDeniedLicense) {
        return n__(
          'LicenseCompliance|License Compliance detected %d new license',
          'LicenseCompliance|License Compliance detected %d new licenses',
          this.licenseReportCount,
        );
      }
      if (this.hasBaseReportLicenses && this.hasDeniedLicense) {
        return n__(
          'LicenseCompliance|License Compliance detected %d new license and policy violation',
          'LicenseCompliance|License Compliance detected %d new licenses and policy violations',
          this.licenseReportCount,
        );
      }
      if (!this.hasBaseReportLicenses && this.hasDeniedLicense) {
        return n__(
          'LicenseCompliance|License Compliance detected %d license and policy violation for the source branch only',
          'LicenseCompliance|License Compliance detected %d licenses and policy violations for the source branch only',
          this.licenseReportCount,
        );
      }
      return n__(
        'LicenseCompliance|License Compliance detected %d license for the source branch only',
        'LicenseCompliance|License Compliance detected %d licenses for the source branch only',
        this.licenseReportCount,
      );
    },
    summaryText() {
      if (this.hasReportItems) {
        return this.summaryTextWithReportItems;
      }

      if (this.hasBaseReportLicenses) {
        return s__('LicenseCompliance|License Compliance detected no new licenses');
      }
      return s__(
        'LicenseCompliance|License Compliance detected no licenses for the source branch only',
      );
    },
    summary() {
      return {
        title: this.summaryText,
      };
    },
    statusIcon() {
      if (this.newLicenses === 0) {
        return EXTENSION_ICONS.success;
      }
      return EXTENSION_ICONS.warning;
    },
    licenseComplianceCollapsedPath() {
      return this.mr.licenseCompliance.license_scanning_comparison_collapsed_path;
    },
    licenseComplianceExpandedPath() {
      return this.mr.licenseCompliance.license_scanning_comparison_path;
    },
  },
  methods: {
    fetchCollapsedData() {
      return axios.get(this.licenseComplianceCollapsedPath).then((res) => {
        this.licenseComplianceData.collapsed = res.data;

        this.$emit('loaded', this.newLicenses);

        return {
          ...res,
          data: res.data,
        };
      });
    },
    fetchExpandedData() {
      return axios(this.licenseComplianceExpandedPath).then((res) => {
        const { data = {} } = res;

        if (isEmpty(data)) {
          return { ...res, data };
        }

        let newLicenses = data.new_licenses;

        newLicenses = newLicenses.map((e) => {
          let supportingText;
          let actions;

          if (
            e.classification.approval_status === LICENSE_APPROVAL_STATUS.ALLOWED ||
            e.classification.approval_status === LICENSE_APPROVAL_STATUS.UNCLASSIFIED
          ) {
            actions = [
              {
                text: n__('Used by %d package', 'Used by %d packages', e.dependencies.length),
                href: this.mr.licenseCompliance.license_scanning.full_report_path,
              },
            ];
          } else {
            supportingText =
              e.dependencies.length > 0
                ? sprintf(s__('License Compliance| Used by %{dependencies}'), {
                    dependencies: parseDependencies(e.dependencies),
                  })
                : '';
          }

          return {
            status: e.classification.approval_status,
            icon: {
              name: APPROVAL_STATUS_TO_ICON[e.classification.approval_status],
            },
            link: {
              href: e.url,
              text: e.name,
            },
            supportingText,
            actions,
          };
        });

        const groupedLicenses = newLicenses.reduce(
          (licenses, license) => ({
            ...licenses,
            [license.status]: [...(licenses[license.status] || []), license],
          }),
          {},
        );

        const licenseSections = [
          ...(groupedLicenses.denied?.length > 0
            ? [
                {
                  header: s__('LicenseCompliance|Denied'),
                  text: s__(
                    "LicenseCompliance|Out-of-compliance with the project's policies and should be removed",
                  ),
                  children: groupedLicenses.denied,
                },
              ]
            : []),
          ...(groupedLicenses.unclassified?.length > 0
            ? [
                {
                  header: s__('LicenseCompliance|Uncategorized'),
                  text: s__('LicenseCompliance|No policy matches this license'),
                  children: groupedLicenses.unclassified,
                },
              ]
            : []),
          ...(groupedLicenses.allowed?.length > 0
            ? [
                {
                  header: s__('LicenseCompliance|Allowed'),
                  text: s__('LicenseCompliance|Acceptable for use in this project'),

                  children: groupedLicenses.allowed,
                },
              ]
            : []),
        ];

        this.licenseComplianceData.expanded = licenseSections;

        return { ...res, data: licenseSections };
      });
    },
  },
  widgetHelpPopover: {
    options: { title: s__('ciReport|License scan results') },
    content: {
      text: s__('ciReport|Detects known vulnerabilities in your software dependencies.'),
      learnMorePath: helpPagePath('user/compliance/license_approval_policies', {
        anchor:
          'criteria-to-compare-licenses-detected-in-the-merge-request-branch-to-licenses-in-the-default-branch',
      }),
    },
  },
};
</script>

<template>
  <mr-widget
    :action-buttons="tertiaryButtons"
    :error-text="$options.i18n.error"
    :loading-text="$options.i18n.loading"
    :fetch-collapsed-data="fetchCollapsedData"
    :fetch-expanded-data="fetchExpandedData"
    :status-icon-name="statusIcon"
    :widget-name="$options.name"
    :summary="summary"
    :is-collapsible="shouldCollapse"
    :content="licenseComplianceData.expanded"
    :help-popover="$options.widgetHelpPopover"
    :label="$options.i18n.label"
    path="license-compliance"
  />
</template>
