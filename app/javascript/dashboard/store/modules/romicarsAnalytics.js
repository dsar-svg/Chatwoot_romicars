import * as types from '../mutation-types';
import RomicarsDashboardAPI from '../../api/romicarsAnalytics';

const state = {
  resolution: null,
};

const getters = {
  getResolution: _state => _state.resolution,
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
};

const mutations = {
  [types.default.SET_ROMICARS_RESOLUTION](_state, data) {
    _state.resolution = data;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
