import { DUO_HEALTH_CHECK_CATEGORIES } from './constants';

export const probesByCategory = (probes) => {
  // Only keep the categories with a probe name included in the category values
  const relevantCategories = DUO_HEALTH_CHECK_CATEGORIES.filter((category) =>
    category.values.some((value) => probes.some((probe) => probe.name === value)),
  );

  return relevantCategories.map((category) => ({
    ...category,
    probes: probes.filter(({ name }) => category.values.includes(name)),
  }));
};
