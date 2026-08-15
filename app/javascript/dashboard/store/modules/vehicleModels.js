import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import VehicleModelAPI from '../../api/vehicleModels';

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
  getModels: _state => _state.records,
  getUIFlags: _state => _state.uiFlags,
};

const actions = {
  get: async function getModels({ commit }, { brandId } = {}) {
    commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { fetchingList: true });
    try {
      const response = await VehicleModelAPI.get({ brandId });
      commit(types.default.SET_VEHICLE_MODELS, response.data.payload);
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { fetchingList: false });
    } catch (error) {
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { fetchingList: false });
      return throwErrorMessage(error);
    }
  },

  create: async function createModel({ commit }, modelObj) {
    commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { creatingItem: true });
    try {
      const response = await VehicleModelAPI.create(modelObj);
      commit(types.default.ADD_VEHICLE_MODEL, response.data.payload);
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { creatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { creatingItem: false });
      return throwErrorMessage(error);
    }
  },

  update: async function updateModel({ commit }, { id, ...updateObj }) {
    commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { updatingItem: true });
    try {
      const response = await VehicleModelAPI.update(id, updateObj);
      commit(types.default.EDIT_VEHICLE_MODEL, response.data.payload);
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { updatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { updatingItem: false });
      return throwErrorMessage(error);
    }
  },

  delete: async function deleteModel({ commit }, id) {
    commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { deletingItem: true });
    try {
      await VehicleModelAPI.delete(id);
      commit(types.default.DELETE_VEHICLE_MODEL, id);
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { deletingItem: false });
    } catch (error) {
      commit(types.default.SET_VEHICLE_MODEL_UI_FLAG, { deletingItem: false });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_VEHICLE_MODEL_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.default.SET_VEHICLE_MODELS]: MutationHelpers.set,
  [types.default.ADD_VEHICLE_MODEL]: MutationHelpers.create,
  [types.default.EDIT_VEHICLE_MODEL]: MutationHelpers.update,
  [types.default.DELETE_VEHICLE_MODEL]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
