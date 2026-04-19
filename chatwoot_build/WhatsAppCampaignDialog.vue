<script setup>
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';
import CampaignsAPI from 'dashboard/api/campaigns';

import WhatsAppCampaignForm from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignForm.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const addCampaign = async campaignDetails => {
  try {
    // Extract CSV file before dispatching
    const csvFile = campaignDetails._csvFile;
    delete campaignDetails._csvFile;

    // Use API directly to get the response with campaign ID
    const response = await CampaignsAPI.create(campaignDetails);
    const campaignId = response?.data?.id;

    // Also add to Vuex store
    store.dispatch('campaigns/get');

    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });

    // If CSV import, upload the file after campaign creation
    if (csvFile && campaignId) {
      try {
        await CampaignsAPI.importCsv(campaignId, csvFile);
        useAlert('Campanha criada e CSV importado com sucesso!');
      } catch (csvError) {
        useAlert('Campanha criada, mas houve um erro ao importar o CSV.');
      }
    } else {
      useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.SUCCESS_MESSAGE'));
    }
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};

const handleSubmit = campaignDetails => {
  addCampaign(campaignDetails);
};

const handleClose = () => emit('close');
</script>

<template>
  <div
    class="w-[28rem] z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] rounded-xl border border-n-weak shadow-md max-h-[80vh] overflow-y-auto"
  >
    <div class="p-6 flex flex-col gap-6">
      <h3 class="text-base font-medium text-n-slate-12 flex-shrink-0">
        {{ t(`CAMPAIGN.WHATSAPP.CREATE.TITLE`) }}
      </h3>
      <WhatsAppCampaignForm @submit="handleSubmit" @cancel="handleClose" />
    </div>
  </div>
</template>
