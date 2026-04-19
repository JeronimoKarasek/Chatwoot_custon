<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { INPUT_TYPES } from 'dashboard/components-next/taginput/helper/tagInputHelper.js';

import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contacts: {
    type: Array,
    required: true,
  },
  selectedContact: {
    type: Object,
    default: null,
  },
  showContactsDropdown: {
    type: Boolean,
    required: true,
  },
  isLoading: {
    type: Boolean,
    required: true,
  },
  isCreatingContact: {
    type: Boolean,
    required: true,
  },
  contactId: {
    type: String,
    default: null,
  },
  contactableInboxesList: {
    type: Array,
    default: () => [],
  },
  showInboxesDropdown: {
    type: Boolean,
    required: true,
  },
  hasErrors: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'searchContacts',
  'setSelectedContact',
  'clearSelectedContact',
  'updateDropdown',
]);

const i18nPrefix = 'COMPOSE_NEW_CONVERSATION.FORM.CONTACT_SELECTOR';
const { t } = useI18n();

const inputType = ref(INPUT_TYPES.EMAIL);

// === New Contact form state ===
const isNewContactMode = ref(false);
const newContactName = ref('');
const newContactPhone = ref('');
const newContactError = ref('');

const contactsList = computed(() => {
  return props.contacts?.map(({ name, id, thumbnail, email, ...rest }) => ({
    id,
    label: email ? `${name} (${email})` : name,
    value: id,
    thumbnail: { name, src: thumbnail },
    ...rest,
    name,
    email,
    action: 'contact',
  }));
});

const selectedContactLabel = computed(() => {
  const { name, email = '', phoneNumber = '' } = props.selectedContact || {};
  if (email) {
    return `${name} (${email})`;
  }
  if (phoneNumber) {
    return `${name} (${phoneNumber})`;
  }
  return name || '';
});

const errorClass = computed(() => {
  return props.hasErrors
    ? '[&_input]:placeholder:!text-n-ruby-9 [&_input]:dark:placeholder:!text-n-ruby-9'
    : '';
});

const handleInput = value => {
  inputType.value = value.startsWith('+') ? INPUT_TYPES.TEL : INPUT_TYPES.EMAIL;
  emit('searchContacts', value);
};

// === New contact methods ===
const toggleNewContactMode = () => {
  isNewContactMode.value = true;
  newContactName.value = '';
  newContactPhone.value = '';
  newContactError.value = '';
};

const cancelNewContactMode = () => {
  isNewContactMode.value = false;
  newContactName.value = '';
  newContactPhone.value = '';
  newContactError.value = '';
};

const handleCreateContact = () => {
  const name = newContactName.value.trim();
  const phone = newContactPhone.value.trim().replace(/[\s\-\(\)]/g, '');

  if (!name) {
    newContactError.value = t(`${i18nPrefix}.NEW_CONTACT.ERROR_NAME`);
    return;
  }
  if (!phone || phone.replace(/[^0-9]/g, '').length < 8) {
    newContactError.value = t(`${i18nPrefix}.NEW_CONTACT.ERROR_PHONE`);
    return;
  }

  // Format phone: ensure it starts with +
  const formattedPhone = phone.startsWith('+') ? phone : '+' + phone;

  newContactError.value = '';

  // NOTE: Do NOT reset isNewContactMode or clear values here.
  // We wait for the parent to confirm success via selectedContact prop.
  emit('setSelectedContact', {
    value: formattedPhone,
    action: 'create',
    customName: name,
  });
};

// Watch: when selectedContact is set (creation succeeded), clear form and exit mode
watch(
  () => props.selectedContact,
  newVal => {
    if (newVal && isNewContactMode.value) {
      isNewContactMode.value = false;
      newContactName.value = '';
      newContactPhone.value = '';
      newContactError.value = '';
    }
  }
);

// Watch: when isCreatingContact goes from true -> false without selectedContact, show error
watch(
  () => props.isCreatingContact,
  (newVal, oldVal) => {
    if (oldVal && !newVal && !props.selectedContact && isNewContactMode.value) {
      newContactError.value = t(`${i18nPrefix}.NEW_CONTACT.ERROR_CREATION`);
    }
  }
);
</script>

<template>
  <div class="relative flex-1 px-4 py-3 overflow-y-visible">
    <div class="flex items-baseline w-full gap-3 min-h-7">
      <label class="text-sm font-medium text-n-slate-11 whitespace-nowrap">
        {{ t(`${i18nPrefix}.LABEL`) }}
      </label>

      <!-- Creating contact spinner/text -->
      <div
        v-if="isCreatingContact"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 px-3 min-h-7 min-w-0"
      >
        <span class="text-sm truncate text-n-slate-12">
          {{ t(`${i18nPrefix}.CONTACT_CREATING`) }}
        </span>
      </div>

      <!-- Selected contact chip -->
      <div
        v-else-if="selectedContact"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 min-h-7 min-w-0"
        :class="!contactId ? 'ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1' : 'px-3'"
      >
        <span class="text-sm truncate text-n-slate-12">
          {{ selectedContactLabel }}
        </span>
        <Button
          v-if="!contactId"
          variant="ghost"
          icon="i-lucide-x"
          color="slate"
          :disabled="contactId"
          size="xs"
          @click="emit('clearSelectedContact')"
        />
      </div>

      <!-- New Contact inline form -->
      <div
        v-else-if="isNewContactMode"
        class="flex flex-col flex-1 gap-2 min-w-0"
      >
        <div class="flex items-center gap-2 flex-1">
          <input
            v-model="newContactName"
            type="text"
            :placeholder="t(`${i18nPrefix}.NEW_CONTACT.NAME_PLACEHOLDER`)"
            class="flex-1 h-7 px-2.5 text-sm rounded-lg border border-n-weak bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand transition-colors min-w-0"
            @keydown.enter="handleCreateContact"
          />
          <input
            v-model="newContactPhone"
            type="tel"
            :placeholder="t(`${i18nPrefix}.NEW_CONTACT.PHONE_PLACEHOLDER`)"
            class="flex-1 h-7 px-2.5 text-sm rounded-lg border border-n-weak bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand transition-colors min-w-0"
            @keydown.enter="handleCreateContact"
          />
          <Button
            v-tooltip="t(`${i18nPrefix}.NEW_CONTACT.CONFIRM`)"
            icon="i-lucide-check"
            variant="faded"
            color="green"
            size="xs"
            @click="handleCreateContact"
          />
          <Button
            v-tooltip="t(`${i18nPrefix}.NEW_CONTACT.CANCEL`)"
            icon="i-lucide-x"
            variant="ghost"
            color="slate"
            size="xs"
            @click="cancelNewContactMode"
          />
        </div>
        <span
          v-if="newContactError"
          class="text-xs text-n-ruby-9"
        >
          {{ newContactError }}
        </span>
      </div>

      <!-- Default: search existing contacts -->
      <TagInput
        v-else
        :placeholder="t(`${i18nPrefix}.TAG_INPUT_PLACEHOLDER`)"
        mode="single"
        :menu-items="contactsList"
        :show-dropdown="showContactsDropdown"
        :is-loading="isLoading"
        :disabled="contactableInboxesList?.length > 0 && showInboxesDropdown"
        allow-create
        :type="inputType"
        class="flex-1 min-h-7"
        :class="errorClass"
        focus-on-mount
        @input="handleInput"
        @on-click-outside="emit('updateDropdown', 'contacts', false)"
        @add="emit('setSelectedContact', $event)"
        @remove="emit('clearSelectedContact')"
      />

      <!-- Toggle: new contact button -->
      <Button
        v-if="!selectedContact && !isCreatingContact && !contactId && !isNewContactMode"
        v-tooltip="t(`${i18nPrefix}.NEW_CONTACT.TOOLTIP`)"
        icon="i-lucide-user-plus"
        variant="ghost"
        color="slate"
        size="xs"
        class="flex-shrink-0"
        @click="toggleNewContactMode"
      />
      <!-- Back to search button -->
      <Button
        v-if="isNewContactMode && !isCreatingContact"
        v-tooltip="t(`${i18nPrefix}.NEW_CONTACT.SEARCH_INSTEAD`)"
        icon="i-lucide-search"
        variant="ghost"
        color="slate"
        size="xs"
        class="flex-shrink-0"
        @click="cancelNewContactMode"
      />
    </div>
  </div>
</template>
