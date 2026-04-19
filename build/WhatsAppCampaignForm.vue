<script setup>
import { reactive, computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
  getFilteredWhatsAppTemplates: useMapGetter(
    'inboxes/getFilteredWhatsAppTemplates'
  ),
};

const initialState = {
  title: '',
  inboxId: null,
  templateId: null,
  scheduledAt: null,
  selectedAudience: [],
  audienceType: 'contact_labels',
  sendingSpeed: 'normal',
};

const state = reactive({ ...initialState });
const templateParserRef = ref(null);
const csvFile = ref(null);
const csvPreview = ref([]);
const csvFileName = ref('');

const audienceRequired = value => {
  if (state.audienceType === 'csv_import') return true;
  return value && value.length > 0;
};

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  templateId: { required },
  selectedAudience: { audienceRequired },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const templateOptions = computed(() => {
  if (!state.inboxId) return [];
  const templates = formState.getFilteredWhatsAppTemplates.value(state.inboxId);
  return templates.map(template => {
    const friendlyName = template.name
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());
    return {
      value: template.id,
      label: `${friendlyName} (${template.language || 'en'})`,
      template: template,
    };
  });
});

const selectedTemplate = computed(() => {
  if (!state.templateId) return null;
  return templateOptions.value.find(option => option.value === state.templateId)
    ?.template;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  template: getErrorMessage('templateId', 'TEMPLATE'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const hasRequiredTemplateParams = computed(() => {
  return templateParserRef.value?.v$?.$invalid === false || true;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasRequiredTemplateParams.value
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  csvFile.value = null;
  csvPreview.value = [];
  csvFileName.value = '';
  v$.value.$reset();
};

const handleCancel = () => emit('cancel');

const contactVariables = [
  { value: '{{contact.name}}', label: '— Nome' },
  { value: '{{contact.phone_number}}', label: '— Telefone' },
  { value: '{{contact.email}}', label: '— Email' },
  { value: '{{contact.company_name}}', label: '— Empresa' },
  { value: '{{contact.city}}', label: '— Cidade' },
  { value: '{{contact.country}}', label: '— País' },
];

const templateHasVariables = computed(() => {
  const params = templateParserRef.value?.processedParams;
  return params?.body && Object.keys(params.body).length > 0;
});

const copyVariable = async value => {
  try {
    await navigator.clipboard.writeText(value);
  } catch {
    // fallback: select text
    const ta = document.createElement('textarea');
    ta.value = value;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  }
};

const audienceTypeOptions = [
  { value: 'contact_labels', label: '🏷️ Etiquetas de Contato' },
  { value: 'conversation_labels', label: '💬 Etiquetas de Conversa' },
  { value: 'csv_import', label: '📄 Importar CSV' },
];

const sendingSpeedOptions = [
  { value: 'normal', label: '🚀 Normal (20/s)' },
  { value: 'slow', label: '🐢 Lento (1/s)' },
  { value: 'human', label: '🧑 Humano (6/min)' },
];

const handleCsvUpload = event => {
  const file = event.target.files[0];
  if (!file) return;
  csvFile.value = file;
  csvFileName.value = file.name;

  const reader = new FileReader();
  reader.onload = e => {
    const text = e.target.result;
    const separator = text.includes(';') ? ';' : ',';
    const lines = text.split('\n').filter(l => l.trim());
    csvPreview.value = lines.slice(0, 6).map(l => l.split(separator));
  };
  reader.readAsText(file);
};

const prepareCampaignDetails = () => {
  const currentTemplate = selectedTemplate.value;
  const parserData = templateParserRef.value;
  const templateContent = parserData?.renderedTemplate || '';

  const templateParams = {
    name: currentTemplate?.name || '',
    namespace: currentTemplate?.namespace || '',
    category: currentTemplate?.category || 'UTILITY',
    language: currentTemplate?.language || 'en_US',
    processed_params: parserData?.processedParams || {},
  };

  const details = {
    title: state.title,
    message: templateContent,
    template_params: templateParams,
    inbox_id: state.inboxId,
    scheduled_at: state.scheduledAt
      ? formatToUTCString(state.scheduledAt)
      : null,
    audience_type: state.audienceType,
    sending_speed: state.sendingSpeed,
  };

  if (state.audienceType !== 'csv_import') {
    details.audience = state.selectedAudience?.map(id => ({
      id,
      type: 'Label',
    }));
  }

  if (state.audienceType === 'csv_import' && csvFile.value) {
    details._csvFile = csvFile.value;
  }

  return details;
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

watch(
  () => state.inboxId,
  () => {
    state.templateId = null;
  }
);
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL') }}
      </label>
      <ComboBox
        v-model="state.templateId"
        :options="templateOptions"
        :has-error="!!formErrors.template"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER')"
        :message="formErrors.template"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.INFO') }}
      </p>
    </div>

    <WhatsAppTemplateParser
      v-if="selectedTemplate"
      ref="templateParserRef"
      :template="selectedTemplate"
    />

    <!-- Contact variable helpers -->
    <div
      v-if="selectedTemplate && templateHasVariables"
      class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-black2 border border-n-weak"
    >
      <p class="text-xs font-medium text-n-slate-12">
        📌 Variáveis de contato (clique para copiar e cole no campo da variável):
      </p>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="cv in contactVariables"
          :key="cv.value"
          type="button"
          class="inline-flex items-center gap-1 px-2 py-1 text-xs font-mono rounded-md border border-n-weak bg-n-alpha-2 hover:bg-n-alpha-3 text-n-slate-12 cursor-pointer transition-colors"
          @click="copyVariable(cv.value)"
        >
          <span class="text-n-blue-11">{{ cv.value }}</span>
          <span class="text-n-slate-11">{{ cv.label }}</span>
        </button>
      </div>
      <p class="text-xs text-n-slate-11">
        Use estas variáveis nos campos acima. Serão substituídas pelos dados de cada contato no envio.
      </p>
    </div>

    <!-- Tipo de Audiência -->
    <div class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        Tipo de Audiência
      </label>
      <ComboBox
        v-model="state.audienceType"
        :options="audienceTypeOptions"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <!-- Labels (Contact or Conversation) -->
    <div
      v-if="state.audienceType !== 'csv_import'"
      class="flex flex-col gap-1"
    >
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL')"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
        :has-error="!!formErrors.audience"
        :message="formErrors.audience"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <!-- CSV Upload -->
    <div
      v-if="state.audienceType === 'csv_import'"
      class="flex flex-col gap-2"
    >
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        Arquivo CSV
      </label>
      <div class="flex items-center gap-2">
        <label
          class="cursor-pointer inline-flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-lg border border-n-weak bg-n-alpha-2 hover:bg-n-alpha-3 text-n-slate-12"
        >
          <span class="i-lucide-upload w-4 h-4" />
          {{ csvFileName || 'Selecionar CSV' }}
          <input
            type="file"
            accept=".csv"
            class="hidden"
            @change="handleCsvUpload"
          />
        </label>
      </div>
      <p class="text-xs text-n-slate-11">
        Colunas obrigatórias: nome, telefone (ex: 11999998888)
      </p>
      <div
        v-if="csvPreview.length > 0"
        class="overflow-x-auto rounded-lg border border-n-weak"
      >
        <table class="w-full text-xs">
          <thead>
            <tr class="bg-n-alpha-2">
              <th
                v-for="(col, ci) in csvPreview[0]"
                :key="ci"
                class="px-2 py-1 text-left font-medium text-n-slate-11"
              >
                {{ col }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(row, ri) in csvPreview.slice(1)"
              :key="ri"
              class="border-t border-n-weak"
            >
              <td
                v-for="(col, ci) in row"
                :key="ci"
                class="px-2 py-1 text-n-slate-12"
              >
                {{ col }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Velocidade de Envio -->
    <div class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        Velocidade de Envio
      </label>
      <ComboBox
        v-model="state.sendingSpeed"
        :options="sendingSpeedOptions"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <!-- Agendamento (opcional) -->
    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL') + ' (opcional)'"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
    />

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
