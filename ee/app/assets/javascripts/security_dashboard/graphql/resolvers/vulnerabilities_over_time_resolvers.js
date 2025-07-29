export default {
  Project: {
    securityMetrics: () => {
      return {
        __typename: 'SecurityMetrics',
      };
    },
  },
  SecurityMetrics: {
    vulnerabilitiesOverTime: async (parent) => {
      // This simulates data from 2025-04-17 to 2025-04-26
      const dates = [
        '2025-04-17',
        '2025-04-18',
        '2025-04-19',
        '2025-04-20',
        '2025-04-21',
        '2025-04-22',
        '2025-04-23',
        '2025-04-24',
        '2025-04-25',
        '2025-04-26',
      ];

      // Get projectIds from parent resolver
      const { projectId = [] } = parent;

      // Mock logic: adjust data based on number of projects
      // If no projects specified, use full data
      // If projects specified, scale data based on number of projects
      const projectMultiplier = projectId.length === 0 ? 1 : Math.max(0.3, projectId.length / 5);

      const severityData = {
        critical: [5, 5, 7, 7, 6, 8, 10, 10, 12, 11].map((val) =>
          Math.round(val * projectMultiplier),
        ),
        high: [25, 27, 30, 30, 28, 31, 35, 35, 38, 36].map((val) =>
          Math.round(val * projectMultiplier),
        ),
        medium: [45, 47, 50, 52, 48, 51, 55, 55, 58, 56].map((val) =>
          Math.round(val * projectMultiplier),
        ),
        low: [65, 68, 72, 72, 69, 73, 78, 78, 82, 79].map((val) =>
          Math.round(val * projectMultiplier),
        ),
        info: [12, 15, 15, 18, 18, 16, 19, 19, 22, 22].map((val) =>
          Math.round(val * projectMultiplier),
        ),
        unknown: [8, 8, 10, 10, 9, 9, 12, 12, 11, 11].map((val) =>
          Math.round(val * projectMultiplier),
        ),
      };

      // simulate data fetching delay
      await new Promise((resolve) => {
        setTimeout(resolve, 1000);
      });

      const result = {
        __typename: 'VulnerabilitiesOverTime',
        nodes: dates.map((date, index) => ({
          __typename: 'VulnerabilityDateData',
          date,
          bySeverity: [
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'CRITICAL',
              count: severityData.critical[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'HIGH',
              count: severityData.high[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'MEDIUM',
              count: severityData.medium[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'LOW',
              count: severityData.low[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'INFO',
              count: severityData.info[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'UNKNOWN',
              count: severityData.unknown[index],
            },
          ],
        })),
      };
      return result;
    },
  },
};
