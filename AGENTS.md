# Chatwoot Development Guidelines

## Deployment Context

This is a **customized Chatwoot v4.16.2** deployment on a VPS using **EasyPanel** with Docker Compose.

### Key Deployment Files
- `docker-compose.easypanel.yml` — Production compose for EasyPanel (uses `chatwoot/chatwoot:latest`)
- `docker-compose.yaml` — Local development compose (builds from source)
- `.github/workflows/publish_custom_docker.yml` — Builds and pushes custom Docker image on push to `claude/init-tvh2q7` branch

### Docker Image Build
- Workflow pushes to `ghcr.io` (GitHub Container Registry)
- Image tags: `latest` and `sha-<commit>`
- Uses `docker/Dockerfile` with multi-stage build (Ruby 3.4.4, Node 24.13.0, pnpm 10.2.0)

### EasyPanel Environment Variables
Production uses these critical env vars (set in EasyPanel):
- `POSTGRES_HOST=postgres`, `REDIS_URL`, `SECRET_KEY_BASE`
- `FRONTEND_URL`, `INSTALLATION_NAME`, `BRAND_NAME`
- `DISABLE_ENTERPRISE=true` (Enterprise overlay disabled)
- `ENABLE_ACCOUNT_SIGNUP=false` (signup disabled by default)
- `RAILS_LOG_TO_STDOUT=true`

### Services Architecture
- **rails** — Main Rails server (port 3000)
- **sidekiq** — Background job processor
- **postgres** — PostgreSQL 16 with pgvector
- **redis** — Redis for caching/queues

## Development Setup

### Quick Start
```bash
# Install dependencies
bundle install && pnpm install

# Start development (requires rbenv, pnpm, overmind)
eval "$(rbenv init -)"
overmind start -f Procfile.dev
```

### Ruby/Node Versions
- Ruby: 3.4.4 (managed via rbenv)
- Node: 24.13.0 (managed via nvm)
- pnpm: 10.2.0

### Essential Commands
```bash
# Linting
pnpm eslint          # JavaScript/Vue
bundle exec rubocop -a  # Ruby

# Testing
pnpm test            # JavaScript tests (vitest)
bundle exec rspec spec/path/to/file_spec.rb  # Ruby tests

# Database
bundle exec rails db:seed          # Seed test data
bundle exec rails db:migrate       # Run migrations
bundle exec rails search:setup_test_data  # Bulk test fixtures
```

## Architecture Notes

### Backend (Rails API)
- **Entry**: `ApplicationController` → `Api::BaseController` → `Api::V1::Accounts::BaseController`
- **Auth**: DeviseTokenAuth
- **Authorization**: Pundit policies in `app/policies/`
- **Events**: Wisper pub/sub via `app/dispatchers/` → `app/listeners/`
- **Jobs**: Sidekiq (`app/jobs/`)
- **Services**: `app/services/` — prefer these over controller logic

### Frontend (Vue 3 SPA)
- **Entry**: `app/javascript/entrypoints/dashboard`
- **State**: Vuex (legacy) + Pinia (new stores)
- **Components**: `dashboard/components-next/` for new UI work
- **Real-time**: ActionCable via `BaseActionCableConnector`

### Key Models
- `Account` — multi-tenant root
- `Inbox` — polymorphic channel (web, email, Facebook, WhatsApp, etc.)
- `Conversation` → `Contact` + `ContactInbox` → `Message`

## Customization Points

### Branding / Logo
- **Logo files replaced** (all with custom PNG from `C:\Users\AUTOMATIZACION\Downloads\loguito.png`):
  - `public/brand-assets/logo.svg` (main logo)
  - `public/brand-assets/logo_dark.svg` (dark mode)
  - `public/brand-assets/logo_thumbnail.svg` (thumbnail)
  - `app/javascript/design-system/images/logo.png`
  - `app/javascript/design-system/images/logo-dark.png`
  - `app/javascript/design-system/images/logo-thumbnail.svg`
  - `app/javascript/widget/assets/images/logo.svg`
  - `app/javascript/dashboard/assets/images/bubble-logo.svg`
  - `public/assets/images/dashboard/captain/logo.svg`
- Use `replaceInstallationName` from `shared/composables/useBranding` for user-facing strings
- Edit `config/locales/en.yml` (backend) and `app/javascript/dashboard/i18n/en.json` (frontend)

### Enterprise Edition
- Enterprise overlay lives in `enterprise/` directory
- Currently disabled in this deployment (`DISABLE_ENTERPRISE=true`)
- When modifying core logic, check `enterprise/` for overrides

## Code Style

- **Ruby**: RuboCop (150 char max line length)
- **Vue/JS**: ESLint (Airbnb + Vue 3)
- **Vue**: Always use Composition API with `<script setup>`
- **Styling**: Tailwind only — no custom CSS, no scoped CSS, no inline styles
- **I18n**: No bare strings in templates

## Common Pitfalls

1. **Database connections**: Production uses `POSTGRES_HOST=postgres` (Docker service name)
2. **Redis auth**: Requires `REDIS_PASSWORD` env var
3. **Asset compilation**: Production Docker image precompiles assets during build
4. **Enterprise code**: Always check `enterprise/` before modifying core models/controllers
5. **Translations**: Only edit `en.yml` and `en.json` — other languages via Crowdin
6. **Components**: Use `components-next/` for new message bubbles and UI work

## Git Workflow

- Branch: `claude/init-tvh2q7` triggers Docker image build
- Commits: Use Conventional Commits format (`type(scope): subject`)
- PRs: Start with user-facing description, add `Closes` section for issues
