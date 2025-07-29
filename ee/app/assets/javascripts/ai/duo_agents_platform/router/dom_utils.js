export const updateActiveNavigation = (href) => {
  const navSection = '#super-sidebar';
  const el = document.querySelector(navSection);

  if (!el) {
    return;
  }

  const activeClass = 'super-sidebar-nav-item-current';
  const activeIndicatorClass = 'active-indicator';

  const currentActiveNavItems = el.querySelectorAll(`.${activeClass}`);
  const currentActiveIndicators = el.querySelectorAll(`.${activeIndicatorClass}`);

  if (currentActiveNavItems.length) {
    currentActiveNavItems.forEach((foundEl) => foundEl.classList.remove(activeClass));
  }

  if (currentActiveIndicators.length) {
    currentActiveIndicators.forEach((foundEl) => foundEl.classList.add('gl-hidden'));
  }

  const newActiveNavItems = el.querySelectorAll(`[href*="${href}"]`);

  if (newActiveNavItems) {
    newActiveNavItems.forEach((foundEl) => {
      foundEl.classList.add(activeClass);
      const newIndicator = foundEl.querySelector(`.${activeIndicatorClass}`);
      if (newIndicator) {
        newIndicator.classList.remove('gl-hidden');
      }
    });
  }
};
