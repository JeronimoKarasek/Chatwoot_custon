import WhatsappTemplatesAPI from '../../api/whatsappTemplatesApi';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

const getters = {
  getTemplates: $state => $state.records,
  getUIFlags: $state => $state.uiFlags,
  getTemplatesByStatus: $state => status =>
    $state.records.filter(t => t.status === status),
  getTemplatesByCategory: $state => category =>
    $state.records.filter(t => t.category === category),
};

const mutations = {
  SET_TEMPLATES(state, templates) {
    state.records = templates;
  },
  ADD_TEMPLATE(state, template) {
    state.records.push(template);
  },
  UPDATE_TEMPLATE(state, updatedTemplate) {
    const index = state.records.findIndex(t => t.id === updatedTemplate.id);
    if (index !== -1) {
      state.records.splice(index, 1, {
        ...state.records[index],
        ...updatedTemplate,
      });
    }
  },
  REMOVE_TEMPLATE(state, templateName) {
    state.records = state.records.filter(t => t.name !== templateName);
  },
  SET_UI_FLAG(state, flag) {
    state.uiFlags = { ...state.uiFlags, ...flag };
  },
};

const actions = {
  async get({ commit }, { inboxId }) {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await WhatsappTemplatesAPI.getAll(inboxId);
      commit('SET_TEMPLATES', response.data.data || []);
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },

  async create({ commit }, { inboxId, template }) {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await WhatsappTemplatesAPI.create(inboxId, template);
      commit('ADD_TEMPLATE', response.data.data);
      return response.data.data;
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },

  async update({ commit }, { inboxId, templateId, template }) {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await WhatsappTemplatesAPI.update(
        inboxId,
        templateId,
        template
      );
      commit('UPDATE_TEMPLATE', response.data.data);
      return response.data.data;
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },

  async delete({ commit }, { inboxId, templateName }) {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await WhatsappTemplatesAPI.delete(inboxId, templateName);
      commit('REMOVE_TEMPLATE', templateName);
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
