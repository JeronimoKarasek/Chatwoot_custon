<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const props = defineProps({
  template: { type: Object, default: null },
  duplicateFrom: { type: Object, default: null },
  isCreating: { type: Boolean, default: false },
  isUpdating: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'close']);

const isEditMode = computed(() => !!props.template);
const sourceTemplate = computed(() => props.template || props.duplicateFrom);

// Form fields
const name = ref('');
const category = ref('MARKETING');
const language = ref('pt_BR');
const headerType = ref('NONE');
const headerText = ref('');
const bodyText = ref('');
const footerText = ref('');
const buttons = ref([]);
const bodyExamples = ref({});
const headerExample = ref('');

// Validation
const errors = ref({});

const LANGUAGES = [
  { code: 'pt_BR', label: 'Português (Brasil)' },
  { code: 'pt_PT', label: 'Português (Portugal)' },
  { code: 'en_US', label: 'English (US)' },
  { code: 'en_GB', label: 'English (UK)' },
  { code: 'es', label: 'Español' },
  { code: 'es_MX', label: 'Español (México)' },
  { code: 'fr', label: 'Français' },
  { code: 'de', label: 'Deutsch' },
  { code: 'it', label: 'Italiano' },
  { code: 'ja', label: '日本語' },
  { code: 'ko', label: '한국어' },
  { code: 'zh_CN', label: '中文 (简体)' },
  { code: 'ar', label: 'العربية' },
  { code: 'hi', label: 'हिन्दी' },
  { code: 'ru', label: 'Русский' },
  { code: 'tr', label: 'Türkçe' },
];

const BUTTON_TYPES = [
  { type: 'QUICK_REPLY', label: 'Resposta Rápida' },
  { type: 'URL', label: 'URL' },
  { type: 'PHONE_NUMBER', label: 'Telefone' },
  { type: 'COPY_CODE', label: 'Copiar Código' },
];

// Max counts by type
const maxButtons = 10;

function canAddButton(type) {
  if (buttons.value.length >= maxButtons) return false;
  const count = buttons.value.filter(b => b.type === type).length;
  if (type === 'URL' && count >= 2) return false;
  if (type === 'PHONE_NUMBER' && count >= 1) return false;
  if (type === 'COPY_CODE' && count >= 1) return false;
  return true;
}

// Body variables
const bodyVariables = computed(() => {
  const matches = bodyText.value.match(/\{\{(\d+)\}\}/g) || [];
  return [...new Set(matches)].map(v => v.replace(/\{\{|\}\}/g, ''));
});

const headerVariables = computed(() => {
  if (headerType.value !== 'TEXT') return [];
  const matches = headerText.value.match(/\{\{(\d+)\}\}/g) || [];
  return [...new Set(matches)].map(v => v.replace(/\{\{|\}\}/g, ''));
});

// Live preview data
const previewComponents = computed(() => {
  const comps = [];
  if (headerType.value !== 'NONE') {
    comps.push({
      type: 'HEADER',
      format: headerType.value,
      text: headerType.value === 'TEXT' ? headerText.value : undefined,
    });
  }
  if (bodyText.value) {
    comps.push({ type: 'BODY', text: bodyText.value });
  }
  if (footerText.value) {
    comps.push({ type: 'FOOTER', text: footerText.value });
  }
  if (buttons.value.length) {
    comps.push({
      type: 'BUTTONS',
      buttons: buttons.value.map(b => ({
        type: b.type,
        text: b.text,
        url: b.url,
        phone_number: b.phone_number,
      })),
    });
  }
  return comps;
});

function addButton(type) {
  if (!canAddButton(type)) return;
  buttons.value.push({
    type,
    text: '',
    url: type === 'URL' ? '' : undefined,
    phone_number: type === 'PHONE_NUMBER' ? '' : undefined,
    example: type === 'COPY_CODE' ? '' : undefined,
  });
}

function removeButton(index) {
  buttons.value.splice(index, 1);
}

function insertVariable(field) {
  if (field === 'body') {
    const currentVars = bodyText.value.match(/\{\{(\d+)\}\}/g) || [];
    const nextNum = currentVars.length + 1;
    bodyText.value += `{{${nextNum}}}`;
  } else if (field === 'header') {
    if (!headerText.value.includes('{{')) {
      headerText.value += '{{1}}';
    }
  }
}

function validate() {
  errors.value = {};

  if (!isEditMode.value) {
    if (!name.value) {
      errors.value.name = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.NAME_REQUIRED');
    } else if (!/^[a-z0-9_]+$/.test(name.value)) {
      errors.value.name = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.NAME_FORMAT');
    } else if (name.value.length > 512) {
      errors.value.name = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.NAME_TOO_LONG');
    }
  }

  if (!bodyText.value) {
    errors.value.body = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.BODY_REQUIRED');
  } else if (bodyText.value.length > 1024) {
    errors.value.body = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.BODY_TOO_LONG');
  }

  if (headerType.value === 'TEXT' && headerText.value.length > 60) {
    errors.value.header = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.HEADER_TOO_LONG');
  }

  if (footerText.value.length > 60) {
    errors.value.footer = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.FOOTER_TOO_LONG');
  }

  // Validate button texts
  buttons.value.forEach((btn, i) => {
    if (!btn.text) {
      errors.value[`button_${i}`] = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.BUTTON_TEXT_REQUIRED');
    } else if (btn.text.length > 25) {
      errors.value[`button_${i}`] = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.BUTTON_TEXT_TOO_LONG');
    }
    if (btn.type === 'URL' && !btn.url) {
      errors.value[`button_url_${i}`] = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.URL_REQUIRED');
    }
    if (btn.type === 'PHONE_NUMBER' && !btn.phone_number) {
      errors.value[`button_phone_${i}`] = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.PHONE_REQUIRED');
    }
  });

  // Validate examples when variables exist
  bodyVariables.value.forEach(v => {
    if (!bodyExamples.value[v]) {
      errors.value[`example_${v}`] = t('WHATSAPP_TEMPLATES.MGMT.FORM.ERRORS.EXAMPLE_REQUIRED');
    }
  });

  return Object.keys(errors.value).length === 0;
}

function buildComponents() {
  const components = [];

  // Header
  if (headerType.value !== 'NONE') {
    const header = { type: 'HEADER', format: headerType.value };
    if (headerType.value === 'TEXT') {
      header.text = headerText.value;
      if (headerVariables.value.length) {
        header.example = {
          header_text: [headerExample.value || 'Example'],
        };
      }
    } else {
      // For media headers - will need handle from upload
      header.example = { header_handle: [] };
    }
    components.push(header);
  }

  // Body
  const body = { type: 'BODY', text: bodyText.value };
  if (bodyVariables.value.length) {
    body.example = {
      body_text: [bodyVariables.value.map(v => bodyExamples.value[v] || 'example')],
    };
  }
  components.push(body);

  // Footer
  if (footerText.value) {
    components.push({ type: 'FOOTER', text: footerText.value });
  }

  // Buttons
  if (buttons.value.length) {
    const buttonsList = buttons.value.map(btn => {
      const b = { type: btn.type, text: btn.text };
      if (btn.type === 'URL') {
        b.url = btn.url;
        if (btn.url?.includes('{{')) {
          b.example = [btn.urlExample || 'https://example.com'];
        }
      }
      if (btn.type === 'PHONE_NUMBER') {
        b.phone_number = btn.phone_number;
      }
      if (btn.type === 'COPY_CODE') {
        b.example = [btn.example || 'CODE123'];
      }
      return b;
    });
    components.push({ type: 'BUTTONS', buttons: buttonsList });
  }

  return components;
}

function handleSubmit() {
  if (!validate()) {
    queueMicrotask(() => {
      const firstErrorField = document.querySelector('.border-n-ruby-7');
      firstErrorField?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      firstErrorField?.focus?.();
    });
    return;
  }

  const data = {
    components: buildComponents(),
  };

  if (!isEditMode.value) {
    data.name = name.value;
    data.category = category.value;
    data.language = language.value;
  }

  emit('submit', data);
}

// Initialize from template
onMounted(() => {
  if (sourceTemplate.value) {
    if (!props.duplicateFrom) {
      name.value = sourceTemplate.value.name || '';
    }
    category.value = sourceTemplate.value.category || 'MARKETING';
    language.value = sourceTemplate.value.language || 'pt_BR';

    const comps = sourceTemplate.value.components || [];

    const header = comps.find(c => c.type === 'HEADER');
    if (header) {
      headerType.value = header.format || 'TEXT';
      headerText.value = header.text || '';
    }

    const body = comps.find(c => c.type === 'BODY');
    if (body) {
      bodyText.value = body.text || '';
    }

    const footer = comps.find(c => c.type === 'FOOTER');
    if (footer) {
      footerText.value = footer.text || '';
    }

    const btns = comps.find(c => c.type === 'BUTTONS');
    if (btns?.buttons) {
      buttons.value = btns.buttons.map(b => ({
        type: b.type,
        text: b.text || '',
        url: b.url || '',
        phone_number: b.phone_number || '',
        example: '',
        urlExample: '',
      }));
    }
  }
});
</script>

<template>
  <div
    class="mb-4 rounded-xl border border-n-weak bg-n-background shadow-sm"
  >
    <div class="w-full">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-n-weak">
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{
              isEditMode
                ? $t('WHATSAPP_TEMPLATES.MGMT.FORM.EDIT_TITLE')
                : $t('WHATSAPP_TEMPLATES.MGMT.FORM.CREATE_TITLE')
            }}
          </h2>
          <button
            type="button"
            class="inline-flex h-8 w-8 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-slate-3"
            @click="emit('close')"
          >
            <span class="i-lucide-x text-sm" />
          </button>
        </div>

        <div class="p-6">
          <div class="space-y-4 min-w-0">
            <!-- Name -->
            <div v-if="!isEditMode">
              <label class="block text-sm font-medium text-n-slate-12 mb-1">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.NAME') }}
              </label>
              <input
                v-model="name"
                type="text"
                :placeholder="$t('WHATSAPP_TEMPLATES.MGMT.FORM.NAME_PLACEHOLDER')"
                class="w-full text-sm border rounded-lg px-3 py-2 bg-n-background text-n-slate-12"
                :class="errors.name ? 'border-n-ruby-7' : 'border-n-weak'"
              />
              <p v-if="errors.name" class="text-xs text-n-ruby-11 mt-1">{{ errors.name }}</p>
              <p class="text-xs text-n-slate-10 mt-1">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.NAME_HINT') }}
              </p>
            </div>
            <div v-else class="bg-n-slate-2 rounded-lg p-3">
              <span class="text-sm text-n-slate-11">Template:</span>
              <span class="text-sm font-medium text-n-slate-12 ml-1">{{ template.name }}</span>
            </div>

            <!-- Category + Language -->
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-1">
                  {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.CATEGORY') }}
                </label>
                <select
                  v-model="category"
                  class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 bg-n-background text-n-slate-12"
                  :disabled="isEditMode && template?.status === 'APPROVED'"
                >
                  <option value="MARKETING">Marketing</option>
                  <option value="UTILITY">Utilidade</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-1">
                  {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.LANGUAGE') }}
                </label>
                <select
                  v-model="language"
                  class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 bg-n-background text-n-slate-12"
                  :disabled="isEditMode"
                >
                  <option v-for="lang in LANGUAGES" :key="lang.code" :value="lang.code">
                    {{ lang.label }}
                  </option>
                </select>
              </div>
            </div>

            <!-- Header -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-1">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.HEADER') }}
              </label>
              <select
                v-model="headerType"
                class="w-full text-sm border border-n-weak rounded-lg px-3 py-2 bg-n-background text-n-slate-12 mb-2"
              >
                <option value="NONE">{{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.HEADER_NONE') }}</option>
                <option value="TEXT">{{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.HEADER_TEXT') }}</option>
                <option value="IMAGE">{{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.HEADER_IMAGE') }}</option>
                <option value="VIDEO">{{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.HEADER_VIDEO') }}</option>
                <option value="DOCUMENT">{{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.HEADER_DOCUMENT') }}</option>
              </select>
              <div v-if="headerType === 'TEXT'" class="relative">
                <input
                  v-model="headerText"
                  type="text"
                  :placeholder="$t('WHATSAPP_TEMPLATES.MGMT.FORM.HEADER_TEXT_PLACEHOLDER')"
                  class="w-full text-sm border rounded-lg px-3 py-2 pr-20 bg-n-background text-n-slate-12"
                  :class="errors.header ? 'border-n-ruby-7' : 'border-n-weak'"
                  maxlength="60"
                />
                <div class="absolute right-2 top-2 flex items-center gap-1">
                  <span class="text-xs text-n-slate-10">{{ headerText.length }}/60</span>
                  <button
                    v-if="!headerText.includes('{' + '{')"
                    class="text-xs text-n-blue-11 hover:text-n-blue-12"
                    type="button"
                    @click="insertVariable('header')"
                  >
                    +var
                  </button>
                </div>
                <p v-if="errors.header" class="text-xs text-n-ruby-11 mt-1">{{ errors.header }}</p>
              </div>
              <div
                v-if="['IMAGE', 'VIDEO', 'DOCUMENT'].includes(headerType)"
                class="bg-n-slate-2 border border-dashed border-n-weak rounded-lg p-4 text-center"
              >
                <span class="i-lucide-cloud-upload text-2xl text-n-slate-9 mb-1" />
                <p class="text-xs text-n-slate-10">
                  {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.MEDIA_HINT') }}
                </p>
              </div>
              <!-- Header variable example -->
              <div v-if="headerVariables.length" class="mt-2">
                <label class="block text-xs font-medium text-n-slate-11 mb-1">
                  {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.EXAMPLE_HEADER') }}
                </label>
                <input
                  v-model="headerExample"
                  type="text"
                  placeholder="Ex: Verão"
                  class="w-full text-sm border border-n-weak rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
                />
              </div>
            </div>

            <!-- Body -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-1">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.BODY') }}
                <span class="text-n-ruby-11">*</span>
              </label>
              <div class="relative">
                <textarea
                  v-model="bodyText"
                  :placeholder="$t('WHATSAPP_TEMPLATES.MGMT.FORM.BODY_PLACEHOLDER')"
                  class="w-full text-sm border rounded-lg px-3 py-2 bg-n-background text-n-slate-12 min-h-[120px] resize-y"
                  :class="errors.body ? 'border-n-ruby-7' : 'border-n-weak'"
                  maxlength="1024"
                />
                <div class="flex items-center justify-between mt-1">
                  <button
                    type="button"
                    class="text-xs text-n-blue-11 hover:text-n-blue-12 flex items-center gap-1"
                    @click="insertVariable('body')"
                  >
                    <span class="i-lucide-plus text-xs" />
                    {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.ADD_VARIABLE') }}
                  </button>
                  <span class="text-xs text-n-slate-10">{{ bodyText.length }}/1024</span>
                </div>
              </div>
              <p v-if="errors.body" class="text-xs text-n-ruby-11 mt-1">{{ errors.body }}</p>
              <p class="text-xs text-n-slate-10 mt-1">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.BODY_HINT') }}
              </p>
            </div>

            <!-- Body variable examples -->
            <div v-if="bodyVariables.length" class="bg-n-slate-2 rounded-lg p-3 space-y-2">
              <label class="block text-xs font-semibold text-n-slate-11">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.EXAMPLES_TITLE') }}
              </label>
              <div v-for="v in bodyVariables" :key="v" class="flex items-center gap-2">
                <span class="text-xs text-n-slate-11 w-12 font-mono" v-text="'{' + '{' + v + '}' + '}'"></span>
                <input
                  v-model="bodyExamples[v]"
                  type="text"
                  :placeholder="`Ex: valor para variável ${v}`"
                  class="flex-1 text-sm border rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
                  :class="errors[`example_${v}`] ? 'border-n-ruby-7' : 'border-n-weak'"
                />
              </div>
              <p class="text-xs text-n-slate-10">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.EXAMPLES_HINT') }}
              </p>
            </div>

            <!-- Footer -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-1">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.FOOTER') }}
              </label>
              <div class="relative">
                <input
                  v-model="footerText"
                  type="text"
                  :placeholder="$t('WHATSAPP_TEMPLATES.MGMT.FORM.FOOTER_PLACEHOLDER')"
                  class="w-full text-sm border rounded-lg px-3 py-2 pr-16 bg-n-background text-n-slate-12"
                  :class="errors.footer ? 'border-n-ruby-7' : 'border-n-weak'"
                  maxlength="60"
                />
                <span class="absolute right-2 top-2.5 text-xs text-n-slate-10">
                  {{ footerText.length }}/60
                </span>
              </div>
              <p v-if="errors.footer" class="text-xs text-n-ruby-11 mt-1">{{ errors.footer }}</p>
            </div>

            <!-- Buttons -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('WHATSAPP_TEMPLATES.MGMT.FORM.BUTTONS') }}
                <span class="text-xs text-n-slate-10 font-normal ml-1">({{ buttons.length }}/{{ maxButtons }})</span>
              </label>

              <div v-for="(btn, idx) in buttons" :key="idx" class="bg-n-slate-2 rounded-lg p-3 mb-2 space-y-2">
                <div class="flex items-center justify-between">
                  <span class="text-xs font-medium text-n-slate-11">
                    {{ BUTTON_TYPES.find(t => t.type === btn.type)?.label || btn.type }}
                  </span>
                  <button
                    type="button"
                    class="text-n-ruby-11 hover:text-n-ruby-12"
                    @click="removeButton(idx)"
                  >
                    <span class="i-lucide-trash-2 text-sm" />
                  </button>
                </div>
                <input
                  v-model="btn.text"
                  type="text"
                  :placeholder="$t('WHATSAPP_TEMPLATES.MGMT.FORM.BUTTON_TEXT_PLACEHOLDER')"
                  class="w-full text-sm border rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
                  :class="errors[`button_${idx}`] ? 'border-n-ruby-7' : 'border-n-weak'"
                  maxlength="25"
                />
                <p v-if="errors[`button_${idx}`]" class="text-xs text-n-ruby-11">{{ errors[`button_${idx}`] }}</p>

                <!-- URL field -->
                <div v-if="btn.type === 'URL'">
                  <input
                    v-model="btn.url"
                    type="text"
                    placeholder="https://example.com/{{1}}"
                    class="w-full text-sm border rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
                    :class="errors[`button_url_${idx}`] ? 'border-n-ruby-7' : 'border-n-weak'"
                  />
                  <p v-if="errors[`button_url_${idx}`]" class="text-xs text-n-ruby-11 mt-1">{{ errors[`button_url_${idx}`] }}</p>
                  <div v-if="btn.url?.includes('{' + '{')">
                    <input
                      v-model="btn.urlExample"
                      type="text"
                      placeholder="Exemplo de URL: https://example.com/12345"
                      class="w-full text-sm border border-n-weak rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12 mt-1"
                    />
                  </div>
                </div>

                <!-- Phone field -->
                <div v-if="btn.type === 'PHONE_NUMBER'">
                  <input
                    v-model="btn.phone_number"
                    type="text"
                    placeholder="+5511999999999"
                    class="w-full text-sm border rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
                    :class="errors[`button_phone_${idx}`] ? 'border-n-ruby-7' : 'border-n-weak'"
                  />
                  <p v-if="errors[`button_phone_${idx}`]" class="text-xs text-n-ruby-11 mt-1">{{ errors[`button_phone_${idx}`] }}</p>
                </div>

                <!-- Copy code field -->
                <div v-if="btn.type === 'COPY_CODE'">
                  <input
                    v-model="btn.example"
                    type="text"
                    :placeholder="$t('WHATSAPP_TEMPLATES.MGMT.FORM.COPY_CODE_PLACEHOLDER')"
                    class="w-full text-sm border border-n-weak rounded-lg px-3 py-1.5 bg-n-background text-n-slate-12"
                    maxlength="15"
                  />
                </div>
              </div>

              <!-- Add button dropdown -->
              <div v-if="buttons.length < maxButtons" class="flex gap-2 flex-wrap">
                <button
                  v-for="btype in BUTTON_TYPES"
                  :key="btype.type"
                  type="button"
                  class="text-xs px-3 py-1.5 border border-dashed border-n-weak rounded-lg text-n-blue-11 hover:bg-n-blue-2 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                  :disabled="!canAddButton(btype.type)"
                  @click="addButton(btype.type)"
                >
                  <span class="i-lucide-plus text-xs mr-1" />
                  {{ btype.label }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex items-center justify-end gap-2 p-4 border-t border-n-weak">
          <Button
            variant="faded"
            :label="$t('WHATSAPP_TEMPLATES.MGMT.FORM.CANCEL')"
            @click="emit('close')"
          />
          <Button
            variant="solid"
            color-scheme="primary"
            :label="
              isEditMode
                ? $t('WHATSAPP_TEMPLATES.MGMT.FORM.UPDATE_BTN')
                : $t('WHATSAPP_TEMPLATES.MGMT.FORM.CREATE_BTN')
            "
            :is-loading="isCreating || isUpdating"
            @click="handleSubmit"
          />
        </div>
    </div>
  </div>
</template>
