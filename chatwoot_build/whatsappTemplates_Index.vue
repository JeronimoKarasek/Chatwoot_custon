<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import TemplateStatusBadge from './components/TemplateStatusBadge.vue';
import TemplateFormDialog from './components/TemplateFormDialog.vue';
import TemplatePreview from './components/TemplatePreview.vue';

const { t } = useI18n();
const store = useStore();

const selectedInboxId = ref(null);
const searchQuery = ref('');
const statusFilter = ref('ALL');
const categoryFilter = ref('ALL');
const showFormDialog = ref(false);
const editingTemplate = ref(null);
const duplicatingTemplate = ref(null);
const previewTemplate = ref(null);
const showPreview = ref(false);

// Computed
const whatsappCloudInboxes = computed(() => {
  const allInboxes = store.getters['inboxes/getInboxes'];
  return allInboxes.filter(
    inbox =>
      inbox.channel_type === 'Channel::Whatsapp' &&
      inbox.provider === 'whatsapp_cloud'
  );
});

const templates = computed(() => store.getters['whatsappTemplates/getTemplates']);
const uiFlags = computed(() => store.getters['whatsappTemplates/getUIFlags']);

const filteredTemplates = computed(() => {
  let result = templates.value;

  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    result = result.filter(t => t.name?.toLowerCase().includes(q));
  }
  if (statusFilter.value !== 'ALL') {
    result = result.filter(t => t.status === statusFilter.value);
  }
  if (categoryFilter.value !== 'ALL') {
    result = result.filter(t => t.category === categoryFilter.value);
  }
  return result;
});

const statusOptions = [
  { label: 'Todos', value: 'ALL' },
  { label: 'Aprovado', value: 'APPROVED' },
  { label: 'Pendente', value: 'PENDING' },
  { label: 'Rejeitado', value: 'REJECTED' },
  { label: 'Pausado', value: 'PAUSED' },
  { label: 'Desabilitado', value: 'DISABLED' },
];

const categoryOptions = [
  { label: 'Todas', value: 'ALL' },
  { label: 'Marketing', value: 'MARKETING' },
  { label: 'Utilidade', value: 'UTILITY' },
];

const templateStats = computed(() => {
  const all = templates.value;
  return {
    total: all.length,
    approved: all.filter(t => t.status === 'APPROVED').length,
    pending: all.filter(t => t.status === 'PENDING').length,
    rejected: all.filter(t => t.status === 'REJECTED').length,
  };
});

const inboxMenuItems = computed(() =>
  whatsappCloudInboxes.value.map(inbox => ({
    label: inbox.name,
    action: () => selectInbox(inbox.id),
  }))
);

const tableHeaders = computed(() => [
  t('WHATSAPP_TEMPLATES.MGMT.TABLE.NAME'),
  t('WHATSAPP_TEMPLATES.MGMT.TABLE.CATEGORY'),
  t('WHATSAPP_TEMPLATES.MGMT.TABLE.LANGUAGE'),
  t('WHATSAPP_TEMPLATES.MGMT.TABLE.STATUS'),
  t('WHATSAPP_TEMPLATES.MGMT.TABLE.BODY'),
  t('WHATSAPP_TEMPLATES.MGMT.TABLE.ACTIONS'),
]);

// Methods
function selectInbox(inboxId) {
  selectedInboxId.value = inboxId;
  fetchTemplates();
}

async function fetchTemplates() {
  if (!selectedInboxId.value) return;
  try {
    await store.dispatch('whatsappTemplates/get', {
      inboxId: selectedInboxId.value,
    });
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATES.MGMT.FETCH_ERROR'));
  }
}

function openCreate() {
  editingTemplate.value = null;
  duplicatingTemplate.value = null;
  showFormDialog.value = true;
}

function openEdit(template) {
  editingTemplate.value = template;
  duplicatingTemplate.value = null;
  showFormDialog.value = true;
}

function openDuplicate(template) {
  duplicatingTemplate.value = template;
  editingTemplate.value = null;
  showFormDialog.value = true;
}

function openPreview(template) {
  previewTemplate.value = template;
  showPreview.value = true;
}

async function handleDelete(template) {
  if (
    !confirm(
      t('WHATSAPP_TEMPLATES.MGMT.DELETE_CONFIRM', { name: template.name })
    )
  )
    return;

  try {
    await store.dispatch('whatsappTemplates/delete', {
      inboxId: selectedInboxId.value,
      templateName: template.name,
    });
    useAlert(t('WHATSAPP_TEMPLATES.MGMT.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATES.MGMT.DELETE_ERROR'));
  }
}

async function handleFormSubmit(templateData) {
  try {
    if (editingTemplate.value) {
      await store.dispatch('whatsappTemplates/update', {
        inboxId: selectedInboxId.value,
        templateId: editingTemplate.value.id,
        template: templateData,
      });
      useAlert(t('WHATSAPP_TEMPLATES.MGMT.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('whatsappTemplates/create', {
        inboxId: selectedInboxId.value,
        template: templateData,
      });
      useAlert(t('WHATSAPP_TEMPLATES.MGMT.CREATE_SUCCESS'));
    }
    showFormDialog.value = false;
    fetchTemplates();
  } catch (error) {
    const msg =
      error?.response?.data?.error ||
      t('WHATSAPP_TEMPLATES.MGMT.SAVE_ERROR');
    useAlert(msg);
  }
}

function handleFormClose() {
  showFormDialog.value = false;
  editingTemplate.value = null;
  duplicatingTemplate.value = null;
}

function getSelectedInboxName() {
  const inbox = whatsappCloudInboxes.value.find(
    i => i.id === selectedInboxId.value
  );
  return inbox ? inbox.name : t('WHATSAPP_TEMPLATES.MGMT.SELECT_INBOX');
}

function getBodyText(template) {
  const body = template.components?.find(c => c.type === 'BODY');
  return body?.text || '';
}

onMounted(() => {
  store.dispatch('inboxes/get');
  if (whatsappCloudInboxes.value.length === 1) {
    selectInbox(whatsappCloudInboxes.value[0].id);
  }
});

watch(whatsappCloudInboxes, newInboxes => {
  if (newInboxes.length === 1 && !selectedInboxId.value) {
    selectInbox(newInboxes[0].id);
  }
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('WHATSAPP_TEMPLATES.MGMT.HEADER')"
        :description="$t('WHATSAPP_TEMPLATES.MGMT.DESCRIPTION')"
      >
        <template #actions>
          <div class="flex items-center gap-2">
            <div class="relative">
              <select
                v-model="selectedInboxId"
                class="text-sm border border-n-weak rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12 min-w-[200px]"
                @change="fetchTemplates"
              >
                <option :value="null" disabled>
                  {{ $t('WHATSAPP_TEMPLATES.MGMT.SELECT_INBOX') }}
                </option>
                <option
                  v-for="inbox in whatsappCloudInboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </div>
            <Button
              v-if="selectedInboxId"
              variant="faded"
              size="sm"
              icon="i-lucide-refresh-cw"
              :is-loading="uiFlags.isFetching"
              @click="fetchTemplates"
            />
            <button
              v-if="selectedInboxId"
              type="button"
              class="inline-flex items-center gap-2 rounded-lg bg-n-brand px-3 py-1.5 text-sm font-medium text-white hover:opacity-90"
              @click="openCreate"
            >
              <span class="i-lucide-plus text-sm" />
              {{ $t('WHATSAPP_TEMPLATES.MGMT.CREATE_BTN') }}
            </button>
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <TemplateFormDialog
        v-if="showFormDialog"
        :template="editingTemplate"
        :duplicate-from="duplicatingTemplate"
        :is-creating="uiFlags.isCreating"
        :is-updating="uiFlags.isUpdating"
        @submit="handleFormSubmit"
        @close="handleFormClose"
      />

      <!-- Stats Cards -->
      <div
        v-if="selectedInboxId && templates.length"
        class="grid grid-cols-4 gap-3 mb-4"
      >
        <div class="bg-n-background border border-n-weak rounded-lg p-3 text-center">
          <div class="text-2xl font-bold text-n-slate-12">{{ templateStats.total }}</div>
          <div class="text-xs text-n-slate-11">Total</div>
        </div>
        <div class="bg-n-background border border-n-weak rounded-lg p-3 text-center">
          <div class="text-2xl font-bold text-n-teal-11">{{ templateStats.approved }}</div>
          <div class="text-xs text-n-slate-11">{{ $t('WHATSAPP_TEMPLATES.MGMT.STATUS.APPROVED') }}</div>
        </div>
        <div class="bg-n-background border border-n-weak rounded-lg p-3 text-center">
          <div class="text-2xl font-bold text-n-amber-11">{{ templateStats.pending }}</div>
          <div class="text-xs text-n-slate-11">{{ $t('WHATSAPP_TEMPLATES.MGMT.STATUS.PENDING') }}</div>
        </div>
        <div class="bg-n-background border border-n-weak rounded-lg p-3 text-center">
          <div class="text-2xl font-bold text-n-ruby-11">{{ templateStats.rejected }}</div>
          <div class="text-xs text-n-slate-11">{{ $t('WHATSAPP_TEMPLATES.MGMT.STATUS.REJECTED') }}</div>
        </div>
      </div>

      <!-- Filters -->
      <div
        v-if="selectedInboxId && templates.length"
        class="flex items-center gap-3 mb-4"
      >
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="$t('WHATSAPP_TEMPLATES.MGMT.SEARCH_PLACEHOLDER')"
          class="text-sm border border-n-weak rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12 w-64"
        />
        <select
          v-model="statusFilter"
          class="text-sm border border-n-weak rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
        >
          <option v-for="opt in statusOptions" :key="opt.value" :value="opt.value">
            {{ opt.label }}
          </option>
        </select>
        <select
          v-model="categoryFilter"
          class="text-sm border border-n-weak rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
        >
          <option v-for="opt in categoryOptions" :key="opt.value" :value="opt.value">
            {{ opt.label }}
          </option>
        </select>
      </div>

      <!-- No inbox selected message -->
      <div
        v-if="!selectedInboxId"
        class="flex flex-col items-center justify-center py-20 text-n-slate-11"
      >
        <span class="i-lucide-inbox text-4xl mb-3" />
        <p class="text-base">{{ $t('WHATSAPP_TEMPLATES.MGMT.NO_INBOX_SELECTED') }}</p>
      </div>

      <div
        v-if="selectedInboxId && !templates.length && !uiFlags.isFetching && !showFormDialog"
        class="flex flex-col items-center justify-center rounded-xl border border-dashed border-n-weak bg-n-slate-2 px-6 py-16 text-center text-n-slate-11"
      >
        <span class="i-lucide-message-square-plus text-4xl mb-3" />
        <p class="text-base font-medium text-n-slate-12 mb-1">
          {{ $t('WHATSAPP_TEMPLATES.MGMT.CREATE_BTN') }}
        </p>
        <p class="text-sm max-w-md">
          Nenhum template encontrado para esta inbox. Clique em Criar Template para cadastrar o primeiro.
        </p>
      </div>

      <!-- Templates Table -->
      <BaseTable
        v-if="selectedInboxId && filteredTemplates.length"
        :headers="tableHeaders"
        :items="filteredTemplates"
        :no-data-message="$t('WHATSAPP_TEMPLATES.MGMT.NO_RESULTS')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="template in items"
            :key="template.id || template.name"
            :item="template"
          >
            <BaseTableCell class="font-medium text-n-slate-12">
              {{ template.name }}
            </BaseTableCell>
            <BaseTableCell>
              <span
                class="px-2 py-0.5 rounded text-xs font-medium"
                :class="
                  template.category === 'MARKETING'
                    ? 'bg-n-violet-3 text-n-violet-11'
                    : 'bg-n-blue-3 text-n-blue-11'
                "
              >
                {{ template.category }}
              </span>
            </BaseTableCell>
            <BaseTableCell>{{ template.language }}</BaseTableCell>
            <BaseTableCell>
              <TemplateStatusBadge :status="template.status" />
            </BaseTableCell>
            <BaseTableCell class="max-w-[300px] truncate text-n-slate-11 text-sm">
              {{ getBodyText(template) }}
            </BaseTableCell>
            <BaseTableCell align="end">
              <div class="flex items-center justify-end gap-1">
                <Button
                  variant="ghost"
                  size="xs"
                  icon="i-lucide-eye"
                  @click="openPreview(template)"
                />
                <Button
                  v-if="['APPROVED', 'REJECTED', 'PAUSED'].includes(template.status)"
                  variant="ghost"
                  size="xs"
                  icon="i-lucide-pencil"
                  @click="openEdit(template)"
                />
                <Button
                  variant="ghost"
                  size="xs"
                  icon="i-lucide-copy"
                  @click="openDuplicate(template)"
                />
                <Button
                  variant="ghost"
                  size="xs"
                  icon="i-lucide-trash-2"
                  color-scheme="alert"
                  @click="handleDelete(template)"
                />
              </div>
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>

      <!-- Empty state after filtering -->
      <div
        v-if="selectedInboxId && !filteredTemplates.length && !uiFlags.isFetching && templates.length"
        class="flex flex-col items-center justify-center py-10 text-n-slate-11"
      >
        <span class="i-lucide-search text-3xl mb-2" />
        <p>{{ $t('WHATSAPP_TEMPLATES.MGMT.NO_RESULTS') }}</p>
      </div>
    </template>
  </SettingsLayout>

  <!-- Preview -->
  <Teleport to="body">
    <div
      v-if="showPreview && previewTemplate"
      class="fixed inset-0 z-50 flex items-center justify-center bg-n-alpha-black2"
      @click.self="showPreview = false"
    >
      <div class="bg-n-background rounded-xl shadow-xl max-w-md w-full mx-4 max-h-[90vh] overflow-auto">
        <div class="flex items-center justify-between p-4 border-b border-n-weak">
          <h3 class="text-base font-semibold text-n-slate-12">
            {{ previewTemplate.name }}
          </h3>
          <Button
            variant="ghost"
            size="xs"
            icon="i-lucide-x"
            @click="showPreview = false"
          />
        </div>
        <div class="p-4">
          <TemplatePreview :template="previewTemplate" />
          <div class="mt-3 flex items-center gap-2">
            <TemplateStatusBadge :status="previewTemplate.status" />
            <span class="text-xs text-n-slate-11">
              {{ previewTemplate.category }} · {{ previewTemplate.language }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
