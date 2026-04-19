<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import CampaignsAPI from 'dashboard/api/campaigns';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import WhatsAppCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import WhatsAppCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/WhatsAppCampaignEmptyState.vue';
import WhatsAppCampaignReportDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignReportDialog.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const selectedCampaign = ref(null);
const [showWhatsAppCampaignDialog, toggleWhatsAppCampaignDialog] = useToggle();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const confirmDeleteCampaignDialogRef = ref(null);
const reportCampaign = ref(null);
const showReportDialog = ref(false);

const handleReport = campaign => {
  reportCampaign.value = campaign;
  showReportDialog.value = true;
};

const WhatsAppCampaigns = computed(
  () => getters['campaigns/getWhatsAppCampaigns'].value
);

const hasNoWhatsAppCampaigns = computed(
  () => WhatsAppCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};

// === Mass Send: Execute + Progress ===
const executingCampaigns = ref({});
const campaignProgress = ref({});
let progressIntervals = {};

const isExecuting = campaignId => !!executingCampaigns.value[campaignId];

const getProgress = campaignId => campaignProgress.value[campaignId] || null;

const isScheduledFuture = campaign => {
  if (!campaign.scheduled_at) return false;
  return new Date(campaign.scheduled_at) > new Date();
};

const canExecute = campaign => {
  return (
    campaign.campaign_status !== 'completed' &&
    !isScheduledFuture(campaign) &&
    !isExecuting(campaign.id)
  );
};

const pollProgress = campaignId => {
  if (progressIntervals[campaignId]) return;
  progressIntervals[campaignId] = setInterval(async () => {
    try {
      const response = await CampaignsAPI.getProgress(campaignId);
      const data = response.data;
      campaignProgress.value = {
        ...campaignProgress.value,
        [campaignId]: data,
      };
      if (data.status === 'completed' || data.status === 'failed') {
        clearInterval(progressIntervals[campaignId]);
        delete progressIntervals[campaignId];
        delete executingCampaigns.value[campaignId];
        executingCampaigns.value = { ...executingCampaigns.value };
        store.dispatch('campaigns/get');
        if (data.status === 'completed') {
          useAlert(`Campanha finalizada! ${data.sent || 0} mensagens enviadas.`);
        }
      }
    } catch {
      clearInterval(progressIntervals[campaignId]);
      delete progressIntervals[campaignId];
    }
  }, 2000);
};

const handleExecute = async campaign => {
  if (!canExecute(campaign)) return;

  executingCampaigns.value = {
    ...executingCampaigns.value,
    [campaign.id]: true,
  };
  campaignProgress.value = {
    ...campaignProgress.value,
    [campaign.id]: { status: 'starting', sent: 0, total: 0, failed: 0 },
  };

  try {
    await CampaignsAPI.execute(campaign.id);
    useAlert('Envio em massa iniciado!');
    pollProgress(campaign.id);
  } catch (error) {
    delete executingCampaigns.value[campaign.id];
    executingCampaigns.value = { ...executingCampaigns.value };
    const msg = error?.response?.data?.error || 'Erro ao iniciar envio.';
    useAlert(msg);
  }
};

const progressPercent = campaignId => {
  const p = getProgress(campaignId);
  if (!p || !p.total || p.total === 0) return 0;
  return Math.round(((p.sent + p.failed) / p.total) * 100);
};

const formatScheduledAt = dateStr => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

onUnmounted(() => {
  Object.values(progressIntervals).forEach(clearInterval);
  progressIntervals = {};
});
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.WHATSAPP.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.WHATSAPP.NEW_CAMPAIGN')"
    @click="toggleWhatsAppCampaignDialog()"
    @close="toggleWhatsAppCampaignDialog(false)"
  >
    <template #action>
      <WhatsAppCampaignDialog
        v-if="showWhatsAppCampaignDialog"
        @close="toggleWhatsAppCampaignDialog(false)"
      />
    </template>
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <div
      v-else-if="!hasNoWhatsAppCampaigns"
      class="flex flex-col gap-4"
    >
      <div
        v-for="campaign in WhatsAppCampaigns"
        :key="campaign.id"
        class="flex flex-col outline-1 outline outline-n-container -outline-offset-1 rounded-xl bg-n-solid-2"
      >
        <!-- Original campaign card content -->
        <div class="flex w-full gap-3 py-5 px-6 flex-row justify-between items-center">
          <div class="flex flex-col items-start justify-between flex-1 min-w-0 gap-2">
            <div class="flex justify-between gap-3 w-fit">
              <span class="text-base font-medium capitalize text-n-slate-12 line-clamp-1">
                {{ campaign.title }}
              </span>
              <span
                class="text-xs font-medium inline-flex items-center h-6 px-2 py-0.5 rounded-md bg-n-alpha-2"
                :class="campaign.campaign_status === 'completed' ? 'text-n-slate-12' : 'text-n-teal-11'"
              >
                {{ campaign.campaign_status === 'completed' ? 'Concluída' : 'Agendada' }}
              </span>
              <span
                v-if="campaign.scheduled_at && campaign.campaign_status !== 'completed'"
                class="text-xs text-n-slate-11 inline-flex items-center gap-1"
              >
                🕐 {{ formatScheduledAt(campaign.scheduled_at) }}
              </span>
            </div>
            <div class="text-sm text-n-slate-11 line-clamp-1 h-6">
              {{ campaign.message }}
            </div>
            <!-- Badges row: speed + audience type -->
            <div class="flex items-center gap-2 flex-wrap">
              <span
                v-if="campaign.sending_speed"
                class="text-xs font-medium px-2 py-0.5 rounded-md bg-n-alpha-2 text-n-slate-11"
              >
                {{ campaign.sending_speed === 'normal' ? '🚀 Normal' : campaign.sending_speed === 'slow' ? '🐢 Lento' : '🧑 Humano' }}
              </span>
              <span
                v-if="campaign.audience_type"
                class="text-xs font-medium px-2 py-0.5 rounded-md bg-n-alpha-2 text-n-slate-11"
              >
                {{ campaign.audience_type === 'conversation_labels' ? '💬 Conv. Labels' : campaign.audience_type === 'csv_import' ? '📄 CSV' : '🏷️ Labels' }}
              </span>
              <span
                v-if="campaign.inbox"
                class="text-xs text-n-slate-11"
              >
                {{ campaign.inbox.name }}
              </span>
            </div>
          </div>
          <div class="flex items-center justify-end gap-2 flex-shrink-0">
            <Button
              v-if="canExecute(campaign)"
              size="sm"
              color="blue"
              icon="i-lucide-send"
              label="Executar"
              :is-loading="isExecuting(campaign.id)"
              @click="handleExecute(campaign)"
            />
            <span
              v-else-if="campaign.campaign_status === 'completed' && !isExecuting(campaign.id)"
              class="text-xs text-n-teal-11 font-medium"
            >
              ✅
            </span>
            <Button
              variant="faded"
              size="sm"
              icon="i-lucide-file-bar-chart"
              label="Relatório"
              @click="handleReport(campaign)"
            />
            <Button
              variant="faded"
              color="ruby"
              size="sm"
              icon="i-lucide-trash"
              @click="handleDelete(campaign)"
            />
          </div>
        </div>
        <!-- Progress bar -->
        <div
          v-if="getProgress(campaign.id)"
          class="px-6 pb-4"
        >
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs text-n-slate-11">
              {{ getProgress(campaign.id).sent || 0 }} enviadas
              <span v-if="getProgress(campaign.id).failed > 0" class="text-n-ruby-11">
                · {{ getProgress(campaign.id).failed }} falhas
              </span>
              · {{ getProgress(campaign.id).total || 0 }} total
            </span>
            <span class="text-xs font-medium text-n-slate-12">
              {{ progressPercent(campaign.id) }}%
            </span>
          </div>
          <div class="w-full bg-n-alpha-3 rounded-full h-2 overflow-hidden">
            <div
              class="h-full rounded-full transition-all duration-500 ease-out"
              :class="getProgress(campaign.id).status === 'completed' ? 'bg-n-teal-9' : getProgress(campaign.id).status === 'failed' ? 'bg-n-ruby-9' : 'bg-n-blue-9'"
              :style="{ width: progressPercent(campaign.id) + '%' }"
            />
          </div>
        </div>
      </div>
    </div>
    <WhatsAppCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
    <WhatsAppCampaignReportDialog
      v-if="showReportDialog && reportCampaign"
      :campaign="reportCampaign"
      @close="showReportDialog = false; reportCampaign = null"
    />
  </CampaignLayout>
</template>
