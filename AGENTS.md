# RomiCards - Chatwoot Custom Deployment

## Que es este proyecto

Personalización completa de **Chatwoot v4.16.2** para la marca **RomiCards**. El sistema de atención al cliente está desplegado en un VPS usando EasyPanel con Docker Compose.

## Marca: RomiCards

- **Nombre**: RomiCards
- **Color primario**: Navy Blue `#1A365D` (light) / `#3B82F6` (dark)
- **Color secundario**: Red `#E53E3E`
- **URL**: romicars.com

## Arquitectura de Despliegue

```
VPS (169.254.0.1)
├── EasyPanel (panel de control)
│   ├── asta_chatwoot-rails-1      → Servidor Rails (puerto 3000)
│   ├── asta_chatwoot-sidekiq-1    → Procesador de jobs
│   ├── asta_chatwoot-postgres-1   → PostgreSQL 16
│   └── asta_chatwoot-redis-1      → Redis
└── Docker Compose (docker-compose.easypanel.yml)
```

### Flujo de Despliegue

1. **Hacer cambios** en el repo local
2. **Commit y push** a la rama `claude/init-tvh2q7`
3. **GitHub Actions** construye y sube la imagen a `ghcr.io/chatgptsupricom-sudo/chatwoot:latest`
4. **En el VPS**: detener contenedores → borrar imagen vieja → pull imagen nueva
5. **Redesplegar** desde EasyPanel
6. **Actualizar base de datos** si es necesario (solo cambios de config)

### Comandos del VPS (ejecutar por SSH)

```bash
# Ver contenedores activos
docker ps --format "table {{.Names}}\t{{.Status}}" | grep chatwoot

# Detener todos los contenedores chatwoot
docker stop $(docker ps -q --filter "name=chatwoot")

# Borrar imagen vieja y pull la nueva
docker rmi ghcr.io/chatgptsupricom-sudo/chatwoot:latest
docker pull ghcr.io/chatgptsupricom-sudo/chatwoot:latest

# Actualizar base de datos (cuando sea necesario)
docker exec asta_chatwoot-rails-1 bundle exec rails runner "InstallationConfig.find_or_create_by(name: 'KEY').update(value: 'VALUE'); GlobalConfig.clear_cache"
```

## Archivos Clave de Branding

### Logos (en `public/brand-assets/`)
| Archivo | Uso | Dimensiones |
|---------|-----|-------------|
| `logo.png` | Favicon y sidebar dashboard | 512x512 px |
| `logotipo.png` | Login y sidebar Super Admin | 400x120 px |

### Configuración de Branding
- `config/installation_config.yml` — Rutas de logos y nombre de instalación
- `config/app.yml` — Versión de la app
- `theme/colors.js` — Colores Tailwind (línea 229: `brand`)
- `app/javascript/dashboard/assets/scss/_next-colors.scss` — Variables CSS
- `app/javascript/widget/assets/scss/woot.scss` — Variables CSS del widget

### Branding en la UI
- `app/javascript/shared/composables/useBranding.js` — Reemplaza "Chatwoot" por nombre de instalación
- `app/views/layouts/vueapp.html.erb` — Favicon y meta tags
- `app/views/super_admin/application/_navigation.html.erb` — Sidebar Super Admin
- `app/views/super_admin/devise/sessions/new.html.erb` — Login Super Admin
- `app/javascript/dashboard/components-next/icon/Logo.vue` — Componente logo
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` — Sidebar dashboard
- `public/manifest.json` — PWA manifest

### Variables de Entorno Críticas (en EasyPanel)
- `POSTGRES_HOST=postgres`
- `POSTGRES_PORT=5432` (requerido para el entrypoint)
- `REDIS_URL`, `SECRET_KEY_BASE`
- `FRONTEND_URL`, `INSTALLATION_NAME`, `BRAND_NAME`
- `DISABLE_ENTERPRISE=true`
- `ENABLE_ACCOUNT_SIGNUP=false`
- `RAILS_LOG_TO_STDOUT=true`

## Bugs Corregidos

### 1. Permisos de entrypoint scripts
- **Problema**: `docker/entrypoints/rails.sh` tenía permisos `100644` en vez de `100755`
- **Causa**: Windows no preserva permisos de ejecución al clonar
- **Fix**: `git update-index --chmod=+x docker/entrypoints/rails.sh`

### 2. POSTGRES_PORT no definido
- **Problema**: `pg_isready -h postgres -p -U postgres` fallaba con "too many arguments"
- **Causa**: EasyPanel no define `POSTGRES_PORT` automáticamente
- **Fix**: Modificar `docker/entrypoints/rails.sh` para omitir `-p` si el puerto está vacío

### 3. Super Admin decía "Chatwoot"
- **Problema**: `_navigation.html.erb` tenía "Chatwoot" hardcodeado
- **Fix**: Cambiar a "RomiCards" y actualizar rutas de logo

## Estilo de Código

- **Ruby**: RuboCop (150 chars max)
- **Vue/JS**: ESLint (Airbnb + Vue 3)
- **Vue**: Siempre Composition API con `<script setup>`
- **Estilos**: Solo Tailwind — sin CSS custom, sin scoped CSS, sin inline styles
- **I18n**: Sin strings bare en templates

## Git Workflow

- **Rama**: `claude/init-tvh2q7` (trigger para GitHub Actions)
- **Commits**: Conventional Commits (`type(scope): subject`)
- **Image tag**: `ghcr.io/chatgptsupricom-sudo/chatwoot:latest`

## Log de Cambios

### 2026-08-10

#### Cambios iniciales
- Creado `AGENTS.md` con contexto del proyecto
- Reemplazados archivos de logo en repo
- Fix permisos entrypoint scripts (`100644` → `100755`)
- Agregado fix para `POSTGRES_PORT` vacío

#### Personalización de marca
- Colores brand aplicados a `_next-colors.scss`, `woot.scss`, `theme/colors.js`
- Variable CSS `--brand-color` agregada para light/dark mode
- `n.brand` en `colors.js` actualizado para usar variable CSS

#### Logos y nombre
- Logo files copiados a `public/brand-assets/`
- `installation_config.yml` actualizado con rutas PNG y nombre RomiCards
- `BRAND_URL` y `WIDGET_BRAND_URL` actualizados a romicars.com
- Meta tags en `vueapp.html.erb` actualizados con color brand
- Versión cambiada de `4.16.2` a `1.0.0` en `config/app.yml`

#### Super Admin
- `_navigation.html.erb` actualizado con nombre RomiCards y logo PNG
- Login Super Admin (`sessions/new.html.erb`) actualizado con logo PNG
- Onboarding page actualizado con RomiCards

#### Favicons
- Todos los favicons reemplazados con `logo.png`
- `manifest.json` actualizado con nombre y colores RomiCards

#### Sidebar
- Logo size aumentado de `size-4` (16px) a `size-5` (20px)

## Pendiente

- [ ] Verificar que los favicons se muestran correctamente después del deploy
- [ ] Confirmar que el sidebar del Super Admin muestra "RomiCards 1.0.0"
- [ ] probar el flujo completo de login → dashboard → configuración
