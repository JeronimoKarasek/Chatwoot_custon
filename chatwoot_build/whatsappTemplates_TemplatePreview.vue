<script setup>
import { computed } from 'vue';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
  liveData: {
    type: Object,
    default: null,
  },
});

const components = computed(() => props.liveData || props.template?.components || []);

const headerComponent = computed(() =>
  components.value.find(c => c.type === 'HEADER')
);

const bodyComponent = computed(() =>
  components.value.find(c => c.type === 'BODY')
);

const footerComponent = computed(() =>
  components.value.find(c => c.type === 'FOOTER')
);

const buttonsComponent = computed(() =>
  components.value.find(c => c.type === 'BUTTONS')
);

function formatText(text) {
  if (!text) return '';
  // Bold
  let formatted = text.replace(/\*([^*]+)\*/g, '<strong>$1</strong>');
  // Italic
  formatted = formatted.replace(/_([^_]+)_/g, '<em>$1</em>');
  // Strikethrough
  formatted = formatted.replace(/~([^~]+)~/g, '<del>$1</del>');
  // Monospace
  formatted = formatted.replace(/```([^`]+)```/g, '<code>$1</code>');
  // Variables highlight
  formatted = formatted.replace(
    /\{\{([^}]+)\}\}/g,
    '<span class="bg-n-amber-3 text-n-amber-11 px-1 rounded text-xs font-mono">{{$1}}</span>'
  );
  // Newlines
  formatted = formatted.replace(/\n/g, '<br>');
  return formatted;
}
</script>

<template>
  <div class="flex justify-center">
    <div class="w-full max-w-[320px]">
      <!-- WhatsApp bubble -->
      <div class="bg-n-teal-2 rounded-lg rounded-tl-none shadow-sm overflow-hidden">
        <!-- Header -->
        <div v-if="headerComponent" class="px-3 pt-2">
          <!-- Media header placeholder -->
          <div
            v-if="['IMAGE', 'VIDEO', 'DOCUMENT'].includes(headerComponent.format)"
            class="bg-n-slate-3 rounded-lg flex items-center justify-center py-8 mb-1"
          >
            <span
              :class="
                headerComponent.format === 'IMAGE'
                  ? 'i-lucide-image'
                  : headerComponent.format === 'VIDEO'
                    ? 'i-lucide-video'
                    : 'i-lucide-file-text'
              "
              class="text-2xl text-n-slate-9"
            />
          </div>
          <!-- Text header -->
          <p
            v-if="headerComponent.format === 'TEXT' || (!headerComponent.format && headerComponent.text)"
            class="font-semibold text-sm text-n-slate-12"
            v-html="formatText(headerComponent.text)"
          />
          <!-- Location header -->
          <div
            v-if="headerComponent.format === 'LOCATION'"
            class="bg-n-slate-3 rounded-lg flex items-center justify-center py-6 mb-1"
          >
            <span class="i-lucide-map-pin text-2xl text-n-slate-9" />
          </div>
        </div>

        <!-- Body -->
        <div v-if="bodyComponent" class="px-3 py-1.5">
          <p
            class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-wrap"
            v-html="formatText(bodyComponent.text)"
          />
        </div>

        <!-- Footer -->
        <div v-if="footerComponent" class="px-3 pb-1.5">
          <p class="text-xs text-n-slate-10">
            {{ footerComponent.text }}
          </p>
        </div>

        <!-- Timestamp -->
        <div class="px-3 pb-1.5 flex justify-end">
          <span class="text-[10px] text-n-slate-9">12:00</span>
        </div>
      </div>

      <!-- Buttons -->
      <div v-if="buttonsComponent?.buttons?.length" class="mt-0.5 space-y-0.5">
        <button
          v-for="(button, idx) in buttonsComponent.buttons"
          :key="idx"
          class="w-full bg-n-background border border-n-weak rounded-lg py-2 px-3 text-sm text-n-blue-11 font-medium flex items-center justify-center gap-1.5 hover:bg-n-slate-2 transition-colors"
        >
          <span
            :class="
              button.type === 'URL'
                ? 'i-lucide-external-link'
                : button.type === 'PHONE_NUMBER'
                  ? 'i-lucide-phone'
                  : button.type === 'COPY_CODE'
                    ? 'i-lucide-copy'
                    : button.type === 'QUICK_REPLY'
                      ? 'i-lucide-reply'
                      : ''
            "
            class="text-xs"
          />
          {{ button.text }}
        </button>
      </div>
    </div>
  </div>
</template>
