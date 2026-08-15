import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import ExchangeRateAPI from '../../api/exchangeRates';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    fetchingCurrent: false,
  },
};

const getters = {
  getRates: _state => _state.records,
  getLatestRate: _state => _state.records[0] || null,
  getUIFlags: _state => _state.uiFlags,
};

const actions = {
  get: async function getRates({ commit }) {
    commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingList: true });
    try {
      const response = await ExchangeRateAPI.get();
      commit(types.default.SET_EXCHANGE_RATES, response.data.payload);
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingList: false });
    } catch (error) {
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingList: false });
      return throwErrorMessage(error);
    }
  },

  fetchCurrent: async function fetchCurrentRate({ commit }) {
    commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingCurrent: true });
    try {
      const response = await ExchangeRateAPI.fetchCurrent();
      commit(types.default.ADD_EXCHANGE_RATE, response.data.payload);
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingCurrent: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_EXCHANGE_RATE_UI_FLAG, { fetchingCurrent: false });
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
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
