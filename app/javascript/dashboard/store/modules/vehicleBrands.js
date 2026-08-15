import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import VehicleBrandAPI from '../../api/vehicleBrands';

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
  getBrands: _state => _state.records,
  getUIFlags: _state => _state.uiFlags,
};

const actions = {
  get: async function getBrands({ commit }) {
    commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { fetchingList: true });
    try {
      const response = await VehicleBrandAPI.get();
      commit(types.default.SET_VEHICLE_BRANDS, response.data.payload);
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { fetchingList: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { fetchingList: false });
      return throwErrorMessage(error);
    }
  },

  create: async function createBrand({ commit }, brandObj) {
    commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { creatingItem: true });
    try {
      const response = await VehicleBrandAPI.create(brandObj);
      commit(types.default.ADD_VEHICLE_BRAND, response.data.payload);
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { creatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { creatingItem: false });
      return throwErrorMessage(error);
    }
  },

  update: async function updateBrand({ commit }, { id, ...updateObj }) {
    commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { updatingItem: true });
    try {
      const response = await VehicleBrandAPI.update(id, updateObj);
      commit(types.default.EDIT_VEHICLE_BRAND, response.data.payload);
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { updatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { updatingItem: false });
      return throwErrorMessage(error);
    }
  },

  delete: async function deleteBrand({ commit }, id) {
    commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { deletingItem: true });
    try {
      await VehicleBrandAPI.delete(id);
      commit(types.default.DELETE_VEHICLE_BRAND, id);
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { deletingItem: false });
      return null;
    } catch (error) {
      commit(types.default.SET_VEHICLE_BRAND_UI_FLAG, { deletingItem: false });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_VEHICLE_BRAND_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.default.SET_VEHICLE_BRANDS]: MutationHelpers.set,
  [types.default.ADD_VEHICLE_BRAND]: MutationHelpers.create,
  [types.default.EDIT_VEHICLE_BRAND]: MutationHelpers.update,
  [types.default.DELETE_VEHICLE_BRAND]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
