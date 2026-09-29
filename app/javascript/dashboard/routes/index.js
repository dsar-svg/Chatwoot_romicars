import { createRouter, createWebHistory, START_LOCATION } from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import { MOBILE_ENTRY_ROUTE } from './dashboard/mobile/mobile.routes';
import store from 'dashboard/store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import { isOnOnboardingView } from 'v3/helpers/RouteHelper';
import AnalyticsHelper from '../helper/AnalyticsHelper';

const ONBOARDING_STEPS = ['account_details', 'enrichment', 'inbox_setup'];
const routes = [...dashboard.routes];

const onboardingPath = step =>
  step === 'inbox_setup' ? 'onboarding/inbox-setup' : 'onboarding';

export const router = createRouter({ history: createWebHistory(), routes });

export const validateAuthenticateRoutePermission = async (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  if (!isLoggedIn) {
    window.location.assign('/app/login');
    return '';
  }

  const { accounts = [], account_id: accountId } = user;

  if (!accounts.length) {
    if (to.name === 'no_accounts') {
      return next();
    }
    return next(frontendURL('no-accounts'));
  }

  const routeAccountId = Number(to.params?.accountId || accountId);
  const userAccount = accounts.find(a => a.id === routeAccountId);
  const isAdmin = userAccount?.role === 'administrator';
  const isActive = userAccount?.status === 'active';
  const needsOnboarding =
    ONBOARDING_STEPS.includes(userAccount?.onboarding_step) &&
    isAdmin &&
    isActive;

  // /app/m has no account in the path (it is the installed app's start URL).
  if (to.name === MOBILE_ENTRY_ROUTE) {
    return next(frontendURL(`accounts/${routeAccountId}/m/conversations`));
  }

  if (to.name === 'no_accounts' || !to.name) {
    const target = needsOnboarding
      ? onboardingPath(userAccount?.onboarding_step)
      : 'dashboard';
    return next(frontendURL(`accounts/${routeAccountId}/${target}`));
  }

  if (needsOnboarding && !isOnOnboardingView(to)) {
    return next(
      frontendURL(
        `accounts/${routeAccountId}/${onboardingPath(userAccount?.onboarding_step)}`
      )
    );
  }
  if (!needsOnboarding && isOnOnboardingView(to)) {
    return next(frontendURL(`accounts/${routeAccountId}/dashboard`));
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

// The installed app opens on its own screens. Logging in, and a start_url Android
// cached from an older manifest, both land on the desktop dashboard; send that
// first load to the mobile list. Later navigation (e.g. "full version") is left alone.
export const isInstalledAppStart = (to, from) =>
  from === START_LOCATION &&
  to.name === 'home' &&
  !!window.matchMedia?.('(display-mode: standalone)').matches;

export const initalizeRouter = () => {
  const userAuthentication = store.dispatch('setUser');

  router.beforeEach(async (to, from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    await userAuthentication;
    if (isInstalledAppStart(to, from)) {
      return next({ name: 'mobile_conversations', params: to.params });
    }
    return validateAuthenticateRoutePermission(to, next, store);
  });
};

export default router;
