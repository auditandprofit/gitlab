/* eslint-disable @gitlab/require-i18n-strings */
export const mockSecurityAttributeCategories = [
  {
    id: 11,
    name: 'Application',
    description: 'Categorize projects by application type and technology stack.',
    multipleSelection: true,
    canEditCategory: false,
    canEditAttributes: true,
    attributeCount: 8,
  },
  {
    id: 12,
    name: 'Business Impact',
    description: 'Classify projects by their importance to business operations.',
    multipleSelection: false,
    canEditCategory: false,
    canEditAttributes: false,
    attributeCount: 5,
  },
  {
    id: 13,
    name: 'Business Unit',
    description: 'Organize projects by owning teams and departments.',
    multipleSelection: true,
    canEditCategory: false,
    canEditAttributes: true,
    attributeCount: 4,
  },
  {
    id: 14,
    name: 'Exposure level',
    description: 'Tag systems based on network accessibility and exposure risk.',
    multipleSelection: false,
    canEditCategory: false,
    canEditAttributes: true,
    attributeCount: 4,
  },
  {
    id: 15,
    name: 'Location',
    description: 'Track system hosting locations and geographic deployment.',
    multipleSelection: false,
    canEditCategory: true,
    canEditAttributes: true,
    attributeCount: 7,
  },
];
export const mockSecurityAttributes = [
  {
    id: 1,
    categoryId: 11,
    name: 'Asset Track',
    description:
      'A comprehensive portfolio management system that monitors client investments and tracks asset performance across multiple markets.',
    color: '#3478C6',
    projectCount: 19,
  },
  {
    id: 2,
    categoryId: 11,
    name: 'Bank Branch',
    description:
      'A branch operations management platform that streamlines teller workflows, queue management, and daily transaction reconciliation.',
    color: '#67AD5C',
    projectCount: 39,
  },
  {
    id: 3,
    categoryId: 11,
    name: 'Capital Commit',
    description:
      'An enterprise lending solution that manages the complete lifecycle of commercial loans from application to disbursement.',
    color: '#EC6337',
    projectCount: 2,
  },
  {
    id: 4,
    categoryId: 11,
    name: 'Deposit Source',
    description:
      'A savings account management system that handles interest calculations, automatic transfers, and customer-facing deposit operations.',
    color: '#613CB1',
    projectCount: 59,
  },
  {
    id: 5,
    categoryId: 11,
    name: 'Fiscal Flow',
    description:
      'A cash management solution that optimizes liquidity forecasting and treasury operations across the banking network.',
    color: '#4994EC',
    projectCount: 38,
  },
  {
    id: 6,
    categoryId: 11,
    name: 'Ledger Link',
    description:
      'A general ledger system that maintains financial records, facilitates account reconciliation, and generates regulatory reports.',
    color: '#F6C444',
    projectCount: 17,
  },
  {
    id: 7,
    categoryId: 11,
    name: 'Vault Version',
    description:
      'A secure document management system for handling sensitive financial agreements, contracts, and compliance documentation.',
    color: '#9031AA',
    projectCount: 42,
  },
  {
    id: 8,
    categoryId: 11,
    name: 'Wealth Ware',
    description:
      'A private banking platform that provides personalized financial planning tools and investment advisory services for high-net-worth clients.',
    color: '#D63865',
    projectCount: 942,
  },
  {
    id: 9,
    categoryId: 12,
    name: 'Mission Critical',
    description: 'Essential for core business functions',
    color: '#A16522',
    projectCount: 3,
  },
  {
    id: 10,
    categoryId: 12,
    name: 'Business Critical',
    description: 'Important for key business operations',
    color: '#B8802F',
    projectCount: 45,
  },
  {
    id: 11,
    categoryId: 12,
    name: 'Business Operational',
    description: 'Standard operational systems',
    color: '#CF9846',
    projectCount: 2,
  },
  {
    id: 12,
    categoryId: 12,
    name: 'Business Administrative',
    description: 'Supporting administrative functions',
    color: '#E2C07F',
    projectCount: 3,
  },
  {
    id: 13,
    categoryId: 12,
    name: 'Non-essential',
    description: 'Minimal business impact',
    color: '#F1DAAE',
    projectCount: 24,
  },
  {
    id: 14,
    categoryId: 15,
    name: 'Canada::Toronto',
    description: 'Distributed team coordination center for Canadian remote workforce.',
    color: '#9B1EC5',
    projectCount: 58,
  },
  {
    id: 15,
    categoryId: 15,
    name: 'Singapore::Singapore',
    description: 'Asia-Pacific regional office covering Southeast Asian operations.',
    color: '#D3875B',
    projectCount: 31,
  },
  {
    id: 16,
    categoryId: 15,
    name: 'UK::London',
    description: 'European headquarters serving UK and European markets.',
    color: '#5FC975',
    projectCount: 13,
  },
  {
    id: 17,
    categoryId: 15,
    name: 'USA::Austin',
    description:
      'Secondary engineering office focused on backend infrastructure and platform development.',
    color: '#3878C2',
    projectCount: 29,
  },
  {
    id: 18,
    categoryId: 15,
    name: 'USA::Denver',
    description: 'Dedicated facility for infrastructure monitoring and cloud services management.',
    color: '#3878C2',
    projectCount: 94,
  },
  {
    id: 19,
    categoryId: 15,
    name: 'USA::New York',
    description: 'East Coast sales and business development operations center.',
    color: '#3878C2',
    projectCount: 28,
  },
  {
    id: 20,
    categoryId: 15,
    name: 'USA::San Francisco',
    description: 'Primary headquarters and main engineering hub in California.',
    color: '#3878C2',
    projectCount: 1,
  },
];

export default {
  Group: {
    securityAttributeCategories() {
      return {
        nodes: mockSecurityAttributeCategories,
      };
    },
    securityAttributes(_, { categoryId }) {
      return {
        nodes: mockSecurityAttributes.filter(
          (node) => categoryId === undefined || node.categoryId === categoryId,
        ),
      };
    },
  },
};
