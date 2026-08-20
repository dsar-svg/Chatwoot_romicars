import * as types from '../mutation-types';

const state = {
  logs: [],
  meta: { total: 0, by_tipo: {}, by_severidad: {} },
};

const getters = {
  getLogs: _state => _state.logs,
  getMeta: _state => _state.meta,
};

const actions = {
  fetchLogs: async function fetchLogs({ commit }, { tipoEvento, severidad, days } = {}) {
    try {
      const response = await axios.get(
        `/api/v1/accounts/${window.location.pathname.split('/')[3]}/bot_logs`,
        { params: { tipo_evento: tipoEvento, severidad, days } }
      );
      commit(types.default.SET_BOT_LOGS, response.data.payload);
      commit(types.default.SET_BOT_LOGS_META, response.data.meta);
      return response.data;
    } catch (error) {
      return null;
    }
  },
};

const mutations = {
  [types.default.SET_BOT_LOGS](_state, logs) {
    _state.logs = logs;
  },
  [types.default.SET_BOT_LOGS_META](_state, meta) {
    _state.meta = meta;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
