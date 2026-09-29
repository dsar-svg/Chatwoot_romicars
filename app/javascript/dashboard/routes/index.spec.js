import {
  validateAuthenticateRoutePermission,
  isInstalledAppStart,
} from './index';
import { START_LOCATION } from 'vue-router';
import store from '../store'; // This import will be mocked
import { vi } from 'vitest';

// Mock the store module
vi.mock('../store', () => ({
  default: {
    getters: {
      isLoggedIn: false,
      getCurrentUser: {
        account_id: null,
        id: null,
        accounts: [],
      },
      'accounts/getAccount': () => ({}),
    },
    dispatch: vi.fn(() => Promise.resolve()),
  },
}));

describe('#validateAuthenticateRoutePermission', () => {
  let next;

  beforeEach(() => {
    next = vi.fn(); // Mock the next function
  });

  describe('when user is not logged in', () => {
    it('should redirect to login', () => {
      const to = { name: 'some-protected-route', params: { accountId: 1 } };

      // Mock the store to simulate user not logged in
      store.getters.isLoggedIn = false;

      // Mock window.location.assign
      const mockAssign = vi.fn();
      delete window.location;
      window.location = { assign: mockAssign };

      validateAuthenticateRoutePermission(to, next);

      expect(mockAssign).toHaveBeenCalledWith('/app/login');
    });
  });

  describe('when user is logged in', () => {
    beforeEach(() => {
      // Mock the store's getter for a logged-in user
      store.getters.isLoggedIn = true;
      store.getters.getCurrentUser = {
        account_id: 1,
        id: 1,
        accounts: [
          {
            id: 1,
            role: 'agent',
            permissions: ['agent'],
            status: 'active',
          },
        ],
      };
    });

    it('sends the installed app entry /app/m to the account', async () => {
      await validateAuthenticateRoutePermission(
        { name: 'mobile_entry', params: {} },
        next
      );

      expect(next).toHaveBeenCalledWith('/app/accounts/1/m/conversations');
    });

    describe('when route is not accessible to current user', () => {
      it('should redirect to dashboard', async () => {
        const to = {
          name: 'general_settings_index',
          params: { accountId: 1 },
          meta: { permissions: ['administrator'] },
        };

        await validateAuthenticateRoutePermission(to, next);

        expect(next).toHaveBeenCalledWith('/app/accounts/1/dashboard');
      });
    });

    describe('when route is accessible to current user', () => {
      beforeEach(() => {
        // Adjust store getters to reflect the user has admin permissions
        store.getters.getCurrentUser = {
          account_id: 1,
          id: 1,
          accounts: [
            {
              id: 1,
              role: 'administrator',
              permissions: ['administrator'],
              status: 'active',
            },
          ],
        };
      });

      it('should go to the intended route', async () => {
        const to = {
          name: 'general_settings_index',
          params: { accountId: 1 },
          meta: { permissions: ['administrator'] },
        };

        await validateAuthenticateRoutePermission(to, next);

        expect(next).toHaveBeenCalledWith();
      });
    });
  });
});

describe('#isInstalledAppStart', () => {
  const home = { name: 'home', params: { accountId: '1' } };
  const setStandalone = matches => {
    window.matchMedia = vi.fn().mockReturnValue({ matches });
  };

  it('sends the installed app first load on the dashboard to mobile', () => {
    setStandalone(true);
    expect(isInstalledAppStart(home, START_LOCATION)).toBe(true);
  });

  it('leaves the browser, later navigation and other routes alone', () => {
    setStandalone(false);
    expect(isInstalledAppStart(home, START_LOCATION)).toBe(false);
    setStandalone(true);
    expect(isInstalledAppStart(home, { name: 'mobile_settings' })).toBe(false);
    expect(
      isInstalledAppStart({ name: 'inbox_conversation' }, START_LOCATION)
    ).toBe(false);
  });
});
