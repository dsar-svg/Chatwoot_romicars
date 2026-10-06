import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import ExchangeRateAPI from '../../api/exchangeRates';

const state = {
  records: [],
  // What the shop adds to the BCV rate for bolivar payments. 13 until the API says otherwise.
  markupPercent: 13,
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    fetchingCurrent: false,
    updatingMarkup: false,
  },
};

const getters = {
  getRates: _state => _state.records,
  getLatestRate: _state => _state.records[0] || null,
  getMarkupPercent: _state => _state.markupPercent,
  getUIFlags: _state => _state.uiFlags,
};

const actions = {
  get: async function getRates({ commit }) {
    commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingList: true });
    try {
      const response = await ExchangeRateAPI.get();
      commit(types.default.SET_EXCHANGE_RATES, response.data.payload);
      commit(
        types.default.SET_EXCHANGE_RATE_MARKUP,
        response.data.meta?.markup_percent
      );
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingList: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingList: false });
      return throwErrorMessage(error);
    }
  },

  // Both actions below reload the list instead of patching it: the latest rate is the
  // first record, and appending the answer left the old one in that place.
  fetchCurrent: async function fetchCurrentRate({ commit, dispatch }) {
    commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingCurrent: true });
    try {
      const response = await ExchangeRateAPI.fetchCurrent();
      await dispatch('get');
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, {
        fetchingCurrent: false,
      });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, {
        fetchingCurrent: false,
      });
      return throwErrorMessage(error);
    }
  },

  updateMarkup: async function updateMarkup({ commit, dispatch }, percent) {
    commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { updatingMarkup: true });
    try {
      await ExchangeRateAPI.updateMarkup(percent);
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, {
        updatingMarkup: false,
      });
      return await dispatch('get');
    } catch (error) {
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, {
        updatingMarkup: false,
      });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_EXCHANGE_RATE_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.default.SET_EXCHANGE_RATES]: MutationHelpers.set,
  [types.default.ADD_EXCHANGE_RATE]: MutationHelpers.create,
  [types.default.SET_EXCHANGE_RATE_MARKUP](_state, percent) {
    if (percent !== undefined && percent !== null) {
      _state.markupPercent = Number(percent);
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
