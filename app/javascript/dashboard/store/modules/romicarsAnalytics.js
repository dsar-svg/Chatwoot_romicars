import * as types from '../mutation-types';
import RomicarsDashboardAPI from '../../api/romicarsAnalytics';

const state = {
  resolution: null,
  requestedProducts: null,
};

const getters = {
  getResolution: _state => _state.resolution,
  getRequestedProducts: _state => _state.requestedProducts,
};

const actions = {
  fetchResolution: async function fetchResolution({ commit }) {
    try {
      const response = await RomicarsDashboardAPI.getResolution();
      commit(types.default.SET_ROMICARS_RESOLUTION, response.data);
      return response.data;
    } catch (error) {
      return null;
    }
  },
  fetchRequestedProducts: async function fetchRequestedProducts({ commit }) {
    try {
      const response = await RomicarsDashboardAPI.getRequestedProducts();
      commit(types.default.SET_ROMICARS_REQUESTED_PRODUCTS, response.data);
      return response.data;
    } catch (error) {
      return null;
    }
  },
};

const mutations = {
  [types.default.SET_ROMICARS_RESOLUTION](_state, data) {
    _state.resolution = data;
  },
  [types.default.SET_ROMICARS_REQUESTED_PRODUCTS](_state, data) {
    _state.requestedProducts = data;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
