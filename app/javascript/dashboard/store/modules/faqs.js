import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import FaqAPI from '../../api/faqs';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
  },
};

const getters = {
  getFaqs: _state => _state.records,
  getUIFlags: _state => _state.uiFlags,
};

const actions = {
  get: async function getFaqs({ commit }, { searchKey, category } = {}) {
    commit(types.default.SET_FAQ_UI_FLAG, { fetchingList: true });
    try {
      const response = await FaqAPI.get({ searchKey, category });
      commit(types.default.SET_FAQS, response.data.payload);
      commit(types.default.SET_FAQ_UI_FLAG, { fetchingList: false });
    } catch (error) {
      commit(types.default.SET_FAQ_UI_FLAG, { fetchingList: false });
      return throwErrorMessage(error);
    }
  },

  create: async function createFaq({ commit }, faqObj) {
    commit(types.default.SET_FAQ_UI_FLAG, { creatingItem: true });
    try {
      const response = await FaqAPI.create(faqObj);
      commit(types.default.ADD_FAQ, response.data.payload);
      commit(types.default.SET_FAQ_UI_FLAG, { creatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_FAQ_UI_FLAG, { creatingItem: false });
      return throwErrorMessage(error);
    }
  },

  update: async function updateFaq({ commit }, { id, ...updateObj }) {
    commit(types.default.SET_FAQ_UI_FLAG, { updatingItem: true });
    try {
      const response = await FaqAPI.update(id, updateObj);
      commit(types.default.EDIT_FAQ, response.data.payload);
      commit(types.default.SET_FAQ_UI_FLAG, { updatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_FAQ_UI_FLAG, { updatingItem: false });
      return throwErrorMessage(error);
    }
  },

  delete: async function deleteFaq({ commit }, id) {
    commit(types.default.SET_FAQ_UI_FLAG, { deletingItem: true });
    try {
      await FaqAPI.delete(id);
      commit(types.default.DELETE_FAQ, id);
      commit(types.default.SET_FAQ_UI_FLAG, { deletingItem: false });
    } catch (error) {
      commit(types.default.SET_FAQ_UI_FLAG, { deletingItem: false });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_FAQ_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.default.SET_FAQS]: MutationHelpers.set,
  [types.default.ADD_FAQ]: MutationHelpers.create,
  [types.default.EDIT_FAQ]: MutationHelpers.update,
  [types.default.DELETE_FAQ]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
