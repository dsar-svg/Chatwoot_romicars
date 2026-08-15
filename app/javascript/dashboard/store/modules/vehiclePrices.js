import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import VehiclePriceAPI from '../../api/vehiclePrices';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
    importing: false,
  },
};

const getters = {
  getPrices: _state => _state.records,
  getUIFlags: _state => _state.uiFlags,
};

const actions = {
  get: async function getPrices({ commit }, { brandId, modelId, search } = {}) {
    commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { fetchingList: true });
    try {
      const response = await VehiclePriceAPI.get({ brandId, modelId, search });
      commit(types.default.SET_VEHICLE_PRICES, response.data.payload);
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { fetchingList: false });
    } catch (error) {
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { fetchingList: false });
      return throwErrorMessage(error);
    }
  },

  create: async function createPrice({ commit }, priceObj) {
    commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { creatingItem: true });
    try {
      const response = await VehiclePriceAPI.create(priceObj);
      commit(types.default.ADD_VEHICLE_PRICE, response.data.payload);
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { creatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { creatingItem: false });
      return throwErrorMessage(error);
    }
  },

  update: async function updatePrice({ commit }, { id, ...updateObj }) {
    commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { updatingItem: true });
    try {
      const response = await VehiclePriceAPI.update(id, updateObj);
      commit(types.default.EDIT_VEHICLE_PRICE, response.data.payload);
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { updatingItem: false });
      return response.data.payload;
    } catch (error) {
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { updatingItem: false });
      return throwErrorMessage(error);
    }
  },

  delete: async function deletePrice({ commit }, id) {
    commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { deletingItem: true });
    try {
      await VehiclePriceAPI.delete(id);
      commit(types.default.DELETE_VEHICLE_PRICE, id);
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { deletingItem: false });
    } catch (error) {
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { deletingItem: false });
      return throwErrorMessage(error);
    }
  },

  import: async function importPrices({ commit }, formData) {
    commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { importing: true });
    try {
      const response = await VehiclePriceAPI.import(formData);
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { importing: false });
      return response.data;
    } catch (error) {
      commit(types.default.SET_VEHICLE_PRICE_UI_FLAG, { importing: false });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_VEHICLE_PRICE_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.default.SET_VEHICLE_PRICES]: MutationHelpers.set,
  [types.default.ADD_VEHICLE_PRICE]: MutationHelpers.create,
  [types.default.EDIT_VEHICLE_PRICE]: MutationHelpers.update,
  [types.default.DELETE_VEHICLE_PRICE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
