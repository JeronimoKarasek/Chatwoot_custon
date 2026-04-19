<script setup>
import { useAlert } from 'dashboard/composables';
import AddCanned from './AddCanned.vue';
import EditCanned from './EditCanned.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref, defineOptions } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({
  name: 'CannedResponseSettings',
});

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const { getPlainText } = useMessageFormatter();

const showAddPopup = ref(false);
const loading = ref({});
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activeResponse = ref({});
const cannedResponseAPI = ref({ message: '' });

const sortOrder = ref('asc');
const searchQuery = ref('');
const activeTab = ref('shared');

const allRecords = computed(() =>
  getters.getCannedResponses.value
);

const sharedRecords = computed(() =>
  getters.getSharedCannedResponses.value
);

const personalRecords = computed(() =>
  getters.getPersonalCannedResponses.value
);

const currentRecords = computed(() => {
  const source = activeTab.value === 'personal' ? personalRecords.value : sharedRecords.value;
  const sorted = [...source].sort((a, b) => {
    if (sortOrder.value === 'asc') {
      return a.short_code.localeCompare(b.short_code);
    }
    return b.short_code.localeCompare(a.short_code);
  });
  return sorted;
});

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return currentRecords.value;
  return picoSearch(currentRecords.value, query, [
    { name: 'short_code', weight: 4 },
    'content',
  ]);
});

const uiFlags = computed(() => getters.getUIFlags.value);

const deleteConfirmText = computed(
  () =>
    `${t('CANNED_MGMT.DELETE.CONFIRM.YES')} ${activeResponse.value.short_code}`
);

const deleteRejectText = computed(
  () =>
    `${t('CANNED_MGMT.DELETE.CONFIRM.NO')} ${activeResponse.value.short_code}`
);

const deleteMessage = computed(() => {
  return ` ${activeResponse.value.short_code} ? `;
});

const toggleSort = () => {
  sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
};

const fetchCannedResponses = async () => {
  try {
    await store.dispatch('getCannedResponse');
  } catch (error) {
    // Ignore Error
  }
};

onMounted(() => {
  fetchCannedResponses();
});

const showAlertMessage = message => {
  loading.value = {};
  activeResponse.value = {};
  cannedResponseAPI.value.message = message;
  useAlert(message);
};

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = response => {
  showEditPopup.value = true;
  activeResponse.value = response;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  activeResponse.value = response;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteCannedResponse = async id => {
  try {
    await store.dispatch('deleteCannedResponse', id);
    showAlertMessage(t('CANNED_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('CANNED_MGMT.DELETE.API.ERROR_MESSAGE');
    showAlertMessage(errorMessage);
  }
};

const confirmDeletion = () => {
  loading.value[activeResponse.value.id] = true;
  closeDeletePopup();
  deleteCannedResponse(activeResponse.value.id);
};

const tableHeaders = computed(() => {
  return [
    t('CANNED_MGMT.LIST.TABLE_HEADER.SHORT_CODE'),
    t('CANNED_MGMT.LIST.TABLE_HEADER.ACTIONS'),
  ];
});

const isAudioResponse = (item) => {
  return item.response_type === 'audio';
};

const playAudio = (item) => {
  if (item.audio_url) {
    const audio = new Audio(item.audio_url);
    audio.play();
  }
};

const recordsCount = computed(() => {
  return currentRecords.value.length;
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="$t('CANNED_MGMT.LOADING')"
    :no-records-found="!allRecords.length"
    :no-records-message="$t('CANNED_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('CANNED_MGMT.HEADER')"
        :description="$t('CANNED_MGMT.DESCRIPTION')"
        :link-text="$t('CANNED_MGMT.LEARN_MORE')"
        :search-placeholder="$t('CANNED_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="canned_responses"
      >
        <template v-if="currentRecords?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('CANNED_MGMT.COUNT', { n: recordsCount }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('CANNED_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <!-- Tabs -->
      <div class="flex gap-1 mb-4 border-b border-n-strong">
        <button
          class="px-4 py-2 text-sm font-medium transition-colors relative"
          :class="activeTab === 'shared'
            ? 'text-n-brand border-b-2 border-n-brand -mb-px'
            : 'text-n-slate-11 hover:text-n-slate-12'"
          @click="activeTab = 'shared'"
        >
          {{ $t('CANNED_MGMT.TABS.SHARED') }}
          <span
            class="ml-1.5 px-1.5 py-0.5 text-xs rounded-full"
            :class="activeTab === 'shared' ? 'bg-n-brand/10 text-n-brand' : 'bg-n-slate-3 text-n-slate-11'"
          >
            {{ sharedRecords.length }}
          </span>
        </button>
        <button
          class="px-4 py-2 text-sm font-medium transition-colors relative"
          :class="activeTab === 'personal'
            ? 'text-n-brand border-b-2 border-n-brand -mb-px'
            : 'text-n-slate-11 hover:text-n-slate-12'"
          @click="activeTab = 'personal'"
        >
          {{ $t('CANNED_MGMT.TABS.PERSONAL') }}
          <span
            class="ml-1.5 px-1.5 py-0.5 text-xs rounded-full"
            :class="activeTab === 'personal' ? 'bg-n-brand/10 text-n-brand' : 'bg-n-slate-3 text-n-slate-11'"
          >
            {{ personalRecords.length }}
          </span>
        </button>
      </div>

      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          !currentRecords.length
            ? activeTab === 'personal'
              ? $t('CANNED_MGMT.LIST.404_PERSONAL')
              : $t('CANNED_MGMT.LIST.404')
            : searchQuery
              ? $t('CANNED_MGMT.NO_RESULTS')
              : ''
        "
      >
        <template #header-0>
          <button
            class="flex items-center gap-2 p-0 cursor-pointer"
            @click="toggleSort"
          >
            <span class="mb-0">
              {{ tableHeaders[0] }}
            </span>
            <Icon
              class="size-5 text-n-slate-11 flex-shrink-0"
              :icon="
                sortOrder === 'desc'
                  ? 'i-woot-sort-descending'
                  : 'i-woot-sort-ascending'
              "
            />
          </button>
        </template>
        <template #header-1>
          {{ tableHeaders[1] }}
        </template>

        <template #row="{ items }">
          <BaseTableRow
            v-for="cannedItem in items"
            :key="cannedItem.id"
            :item="cannedItem"
          >
            <template #default>
              <BaseTableCell class="max-w-0">
                <div class="flex flex-col gap-2 min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="text-heading-3 text-n-slate-12 truncate block">
                      {{ cannedItem.short_code }}
                    </span>
                    <span
                      v-if="isAudioResponse(cannedItem)"
                      class="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium rounded-full bg-n-violet-2 text-n-violet-11"
                    >
                      🎤 {{ $t('CANNED_MGMT.AUDIO.BADGE') }}
                    </span>
                    <span
                      v-if="cannedItem.personal"
                      class="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium rounded-full bg-n-amber-2 text-n-amber-11"
                    >
                      {{ $t('CANNED_MGMT.PERSONAL_BADGE') }}
                    </span>
                  </div>
                  <div v-if="isAudioResponse(cannedItem) && cannedItem.audio_url" class="flex items-center gap-2">
                    <button
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-n-slate-2 hover:bg-n-slate-3 text-n-slate-12 transition-colors"
                      @click.stop="playAudio(cannedItem)"
                    >
                      ▶ {{ $t('CANNED_MGMT.AUDIO.PLAY') }}
                    </button>
                  </div>
                  <p v-else class="text-body-main text-n-slate-11 line-clamp-5">
                    {{ getPlainText(cannedItem.content) }}
                  </p>
                </div>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-24">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('CANNED_MGMT.EDIT.BUTTON_TEXT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(cannedItem)"
                  />
                  <Button
                    v-tooltip.top="$t('CANNED_MGMT.DELETE.BUTTON_TEXT')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[cannedItem.id]"
                    @click="openDeletePopup(cannedItem)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddCanned
        :on-close="hideAddPopup"
        :default-personal="activeTab === 'personal'"
      />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditCanned
        v-if="showEditPopup"
        :id="activeResponse.id"
        :edshort-code="activeResponse.short_code"
        :edcontent="activeResponse.content"
        :edresponse-type="activeResponse.response_type || 'text'"
        :edpersonal="activeResponse.personal || false"
        :edaudio-url="activeResponse.audio_url || ''"
        :on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('CANNED_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('CANNED_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </SettingsLayout>
</template>
