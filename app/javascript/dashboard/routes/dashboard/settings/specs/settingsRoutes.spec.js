import { createRouter, createMemoryHistory } from 'vue-router';
import settings from '../settings.routes';

// Several settings pages import the app router, which imports settings.routes. Loaded on
// its own here, that cycle hands back undefined; the app boots through the router first
// and never sees it.
vi.mock('dashboard/routes/index', () => ({ default: {}, router: {} }));

describe('settings routes', () => {
  // The sidebar resolves every link it renders; a name that is not registered throws and
  // takes the whole Settings group down with it.
  it('registers the conversation workflow page the sidebar links to', () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: settings.routes,
    });
    const route = router.resolve({
      name: 'conversation_workflow_index',
      params: { accountId: 1 },
    });

    expect(route.path).toBe('/app/accounts/1/settings/conversation-workflow');
    expect(route.meta.permissions).toEqual(['administrator']);
  });
});
