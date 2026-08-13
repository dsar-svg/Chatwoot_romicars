<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { useBranding } from 'shared/composables/useBranding';
import AnalyticsHelper from 'dashboard/helper/AnalyticsHelper';
import { SESSION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';
import SessionLimitOverlay from 'dashboard/components/auth/SessionLimitOverlay.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const USER_NOT_CONFIRMED_ERROR_CODE = 'user_not_confirmed';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    SimpleDivider,
    MfaVerification,
    SessionLimitOverlay,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
      sessionsLimitReached: false,
      limitedSessions: [],
    };
  },
  validations() {
    return {
      credentials: {
        password: { required },
        email: { required, email },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      this.requestIdleCallbackPolyfill(() => {
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }
          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (response?.errorCode === USER_NOT_CONFIRMED_ERROR_CODE) {
            this.loginApi.showLoading = false;
            this.$router.push({
              name: 'auth_verify_email',
              state: { email: credentials.email },
            });
            return;
          }
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }
      this.submitLogin();
    },
    handleMfaVerified() {
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
    retryLoginWithParams(extraParams) {
      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
        ...extraParams,
      };
      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.loginApi.showLoading = true;
      login(credentials)
        .then(result => {
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }
          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    handleSessionRevoke(sessionId) {
      this.retryLoginWithParams({ revoke_session_id: sessionId });
    },
    handleSessionRevokeAll() {
      this.retryLoginWithParams({ revoke_all_sessions: true });
    },
    handleSessionLimitCancel() {
      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <main class="romicars-login-root">
    <!-- Animated background -->
    <div class="romicars-bg" aria-hidden="true">
      <div class="romicars-orb orb-1" />
      <div class="romicars-orb orb-2" />
      <div class="romicars-orb orb-3" />
      <div class="romicars-orb orb-4" />
      <!-- Floating particles -->
      <div class="romicars-p p-1" />
      <div class="romicars-p p-2" />
      <div class="romicars-p p-3" />
      <div class="romicars-p p-4" />
      <div class="romicars-p p-5" />
      <div class="romicars-p p-6" />
      <div class="romicars-p p-7" />
      <div class="romicars-p p-8" />
      <div class="romicars-p p-9" />
      <div class="romicars-p p-10" />
    </div>

    <!-- Session Limit Section -->
    <section v-if="sessionsLimitReached" class="romicars-overlay-section">
      <SessionLimitOverlay
        :sessions="limitedSessions"
        @revoke="handleSessionRevoke"
        @revoke-all="handleSessionRevokeAll"
        @cancel="handleSessionLimitCancel"
      />
    </section>

    <!-- MFA Verification Section -->
    <section v-else-if="mfaRequired" class="romicars-overlay-section">
      <MfaVerification
        :mfa-token="mfaToken"
        @verified="handleMfaVerified"
        @cancel="handleMfaCancel"
      />
    </section>

    <!-- Login Card -->
    <section
      v-else
      class="romicars-card"
      :class="{ 'animate-wiggle': loginApi.hasErrored }"
    >
      <!-- Logo -->
      <div class="flex justify-center mb-8">
        <img
          :src="globalConfig.logo"
          :alt="globalConfig.installationName"
          class="h-10 w-auto max-w-[180px]"
        />
      </div>

      <!-- Title & subtitle -->
      <h1 class="romicars-title">
        {{ replaceInstallationName($t('LOGIN.TITLE')) }}
      </h1>
      <p class="romicars-subtitle">Accede al panel de gestión</p>

      <!-- Form -->
      <div v-if="!email">
        <div v-if="showGoogleOAuth || showSamlLogin" class="flex flex-col gap-4 mb-6">
          <GoogleOAuthButton v-if="showGoogleOAuth" />
          <div v-if="showSamlLogin" class="text-center">
            <router-link
              to="/app/login/sso"
              class="inline-flex justify-center w-full px-4 py-3 items-center bg-slate-100 rounded-lg ring-1 ring-inset ring-slate-200 hover:bg-slate-50 transition-colors"
            >
              <Icon icon="i-lucide-lock-keyhole" class="size-5 text-slate-500" />
              <span class="ml-2 text-base font-medium text-slate-700">
                {{ $t('LOGIN.SAML.LABEL') }}
              </span>
            </router-link>
          </div>
          <SimpleDivider :label="$t('COMMON.OR')" class="uppercase" />
        </div>

        <form class="space-y-5" @submit.prevent="submitFormLogin">
          <FormInput
            v-model="credentials.email"
            name="email_address"
            type="text"
            data-testid="email_input"
            :tabindex="1"
            required
            :label="$t('LOGIN.EMAIL.LABEL')"
            :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
            :has-error="v$.credentials.email.$error"
            @input="v$.credentials.email.$touch"
          />
          <FormInput
            v-model="credentials.password"
            type="password"
            name="password"
            data-testid="password_input"
            required
            :tabindex="2"
            :label="$t('LOGIN.PASSWORD.LABEL')"
            :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
            :has-error="v$.credentials.password.$error"
            @input="v$.credentials.password.$touch"
          >
            <p v-if="!globalConfig.disableUserProfileUpdate">
              <router-link
                to="auth/reset/password"
                class="text-sm text-blue-500 hover:underline"
                tabindex="4"
              >
                {{ $t('LOGIN.FORGOT_PASSWORD') }}
              </router-link>
            </p>
          </FormInput>

          <button
            type="submit"
            :tabindex="3"
            :disabled="loginApi.showLoading"
            data-testid="submit_button"
            class="romicars-submit-btn"
          >
            <Spinner
              v-if="loginApi.showLoading"
              color-scheme="primary"
              size="sm"
              class="mr-2"
            />
            {{ $t('LOGIN.SUBMIT') }}
          </button>
        </form>

        <p v-if="showSignupLink" class="mt-5 text-sm text-center text-slate-400">
          {{ $t('COMMON.OR') }}
          <router-link
            to="auth/signup"
            class="text-blue-500 hover:underline lowercase"
          >
            {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
          </router-link>
        </p>
      </div>

      <div v-else class="flex items-center justify-center py-10">
        <Spinner color-scheme="primary" size="" />
      </div>

      <!-- Footer -->
      <p class="mt-8 text-xs text-center text-slate-400">
        Plataforma de gestión de clientes © Romicars
      </p>
    </section>
  </main>
</template>

<style>
/* =============================================
   ROMICARS LOGIN — Animated dark background
   ============================================= */

.romicars-login-root {
  min-height: 100vh;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #0c1220;
  position: relative;
  overflow: hidden;
  padding: 2rem 1rem;
}

/* ---- Animated background layer ---- */
.romicars-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

/* ---- Orbs ---- */
.romicars-orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(90px);
  will-change: transform, opacity;
}

.orb-1 {
  width: 72vw;
  height: 72vw;
  background: radial-gradient(
    circle at 40% 40%,
    rgba(99, 102, 241, 0.3) 0%,
    transparent 68%
  );
  top: -30%;
  left: -18%;
  animation:
    orb-1-move 18s ease-in-out infinite alternate,
    orb-pulse 8s ease-in-out infinite alternate;
}

.orb-2 {
  width: 58vw;
  height: 58vw;
  background: radial-gradient(
    circle at 55% 55%,
    rgba(147, 51, 234, 0.25) 0%,
    transparent 68%
  );
  bottom: -24%;
  right: -12%;
  animation:
    orb-2-move 24s ease-in-out infinite alternate,
    orb-pulse 11s ease-in-out infinite alternate;
  animation-delay: -6s, -4s;
}

.orb-3 {
  width: 42vw;
  height: 42vw;
  background: radial-gradient(
    circle at 50% 50%,
    rgba(220, 38, 38, 0.18) 0%,
    transparent 68%
  );
  top: 18%;
  right: 20%;
  animation:
    orb-3-move 21s ease-in-out infinite alternate,
    orb-pulse 7s ease-in-out infinite alternate;
  animation-delay: -10s, -2s;
}

.orb-4 {
  width: 38vw;
  height: 38vw;
  background: radial-gradient(
    circle at 50% 50%,
    rgba(14, 165, 233, 0.13) 0%,
    transparent 68%
  );
  bottom: 8%;
  left: 5%;
  animation: orb-4-move 27s ease-in-out infinite alternate;
  animation-delay: -14s;
}

@keyframes orb-1-move {
  0%   { transform: translate(0, 0) scale(1); }
  40%  { transform: translate(8vw, 10vh) scale(1.06); }
  100% { transform: translate(5vw, 18vh) scale(0.94); }
}
@keyframes orb-2-move {
  0%   { transform: translate(0, 0) scale(1); }
  50%  { transform: translate(-12vw, -9vh) scale(1.08); }
  100% { transform: translate(-7vw, -16vh) scale(0.92); }
}
@keyframes orb-3-move {
  0%   { transform: translate(0, 0) scale(1); }
  35%  { transform: translate(-9vw, 9vh) scale(1.1); }
  100% { transform: translate(9vw, -8vh) scale(0.9); }
}
@keyframes orb-4-move {
  0%   { transform: translate(0, 0); }
  100% { transform: translate(13vw, -11vh); }
}
@keyframes orb-pulse {
  0%   { opacity: 0.5; }
  100% { opacity: 1; }
}

/* ---- Floating particles ---- */
.romicars-p {
  position: absolute;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.2);
  animation: particle-float linear infinite;
  will-change: transform, opacity;
}

.p-1  { width: 3px;  height: 3px;  left: 9%;  top: 88%; animation-duration: 12s; animation-delay: 0s; }
.p-2  { width: 2px;  height: 2px;  left: 20%; top: 91%; animation-duration: 16s; animation-delay: -3s; }
.p-3  { width: 4px;  height: 4px;  left: 36%; top: 87%; animation-duration: 10s; animation-delay: -7s; }
.p-4  { width: 2px;  height: 2px;  left: 50%; top: 94%; animation-duration: 14s; animation-delay: -1s; }
.p-5  { width: 3px;  height: 3px;  left: 63%; top: 86%; animation-duration: 11s; animation-delay: -9s; }
.p-6  { width: 5px;  height: 5px;  left: 78%; top: 80%; animation-duration: 18s; animation-delay: -5s; }
.p-7  { width: 2px;  height: 2px;  left: 29%; top: 96%; animation-duration: 13s; animation-delay: -6s; }
.p-8  { width: 3px;  height: 3px;  left: 71%; top: 83%; animation-duration: 9s;  animation-delay: -2s; }
.p-9  { width: 2px;  height: 2px;  left: 44%; top: 89%; animation-duration: 15s; animation-delay: -11s; }
.p-10 { width: 4px;  height: 4px;  left: 86%; top: 90%; animation-duration: 12s; animation-delay: -8s; }

@keyframes particle-float {
  0%   { transform: translateY(0) translateX(0);     opacity: 0; }
  6%   { opacity: 0.9; }
  88%  { opacity: 0.3; }
  100% { transform: translateY(-96vh) translateX(25px); opacity: 0; }
}

/* ---- Overlay sections (MFA / session limit) ---- */
.romicars-overlay-section {
  position: relative;
  z-index: 10;
  width: 100%;
  max-width: 32rem;
  margin: 0 auto;
  padding: 0 1rem;
}

/* ---- White card ---- */
.romicars-card {
  position: relative;
  z-index: 10;
  background: #ffffff;
  border-radius: 18px;
  padding: 2.75rem 2.5rem;
  width: 100%;
  max-width: 450px;
  box-shadow:
    0 32px 80px rgba(0, 0, 0, 0.55),
    0 0 0 1px rgba(255, 255, 255, 0.06),
    inset 0 1px 0 rgba(255, 255, 255, 0.6);
}

/* Force light appearance inside the white card */
.romicars-card input[type='text'],
.romicars-card input[type='email'],
.romicars-card input[type='password'] {
  background-color: #eef2f7 !important;
  color: #1e293b !important;
  border-color: #dde3ed !important;
}
.romicars-card input[type='text']:focus,
.romicars-card input[type='email']:focus,
.romicars-card input[type='password']:focus {
  border-color: #6366f1 !important;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15) !important;
  outline: none !important;
}
.romicars-card label {
  color: #374151 !important;
}
.romicars-card p,
.romicars-card span {
  color: inherit;
}

/* ---- Card typography ---- */
.romicars-title {
  font-size: 1.5rem;
  font-weight: 700;
  text-align: center;
  color: #1a202c;
  letter-spacing: -0.02em;
  margin-bottom: 0.25rem;
}
.romicars-subtitle {
  font-size: 0.875rem;
  text-align: center;
  color: #94a3b8;
  margin-bottom: 2rem;
}

/* ---- Red submit button ---- */
.romicars-submit-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.8rem 1rem;
  background: #dc2626;
  color: #ffffff;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition:
    background 0.18s ease,
    transform 0.1s ease,
    box-shadow 0.18s ease;
  letter-spacing: 0.02em;
}
.romicars-submit-btn:hover:not(:disabled) {
  background: #b91c1c;
  box-shadow: 0 4px 16px rgba(220, 38, 38, 0.45);
}
.romicars-submit-btn:active:not(:disabled) {
  transform: scale(0.98);
}
.romicars-submit-btn:disabled {
  opacity: 0.65;
  cursor: not-allowed;
}

/* ---- Reduced motion ---- */
@media (prefers-reduced-motion: reduce) {
  .romicars-orb,
  .romicars-p {
    animation: none !important;
  }
}
</style>
