<script setup>
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import { onMounted, ref, computed } from 'vue';

const isProcessing = ref(false);
const buttonLabel = ref('');
const buttonError = ref(false);

const accountId = computed(() => {
  const match = window.location.pathname.match(/\/accounts\/(\d+)/);
  return match ? match[1] : null;
});

function getAuthHeaders() {
  const h = { 'Content-Type': 'application/json' };
  try {
    for (const c of document.cookie.split(';')) {
      const t = c.trim();
      if (t.startsWith('cw_d_session_info=')) {
        const d = JSON.parse(decodeURIComponent(t.substring(18)));
        if (d && d['access-token']) {
          h['access-token'] = d['access-token'];
          h['token-type'] = d['token-type'];
          h['client'] = d['client'];
          h['expiry'] = d['expiry'];
          h['uid'] = d['uid'];
        }
      }
    }
  } catch (e) {
    // ignore
  }
  return h;
}

async function goToCheckout() {
  if (!accountId.value) {
    buttonLabel.value = 'Erro: conta não identificada';
    buttonError.value = true;
    setTimeout(resetButton, 3000);
    return;
  }

  isProcessing.value = true;
  buttonLabel.value = 'Redirecionando...';
  buttonError.value = false;

  try {
    const r = await fetch(
      `/enterprise/api/v1/accounts/${accountId.value}/checkout`,
      {
        method: 'POST',
        headers: getAuthHeaders(),
        credentials: 'same-origin',
        body: JSON.stringify({}),
      }
    );
    const d = await r.json();
    if (d.redirect_url) {
      window.open(d.redirect_url, '_blank');
      resetButton();
    } else if (d.error) {
      buttonLabel.value = d.error;
      buttonError.value = true;
      setTimeout(resetButton, 3000);
    } else {
      resetButton();
    }
  } catch (e) {
    buttonLabel.value = 'Erro de conexão';
    buttonError.value = true;
    setTimeout(resetButton, 3000);
  }
  isProcessing.value = false;
}

function resetButton() {
  buttonLabel.value = '';
  buttonError.value = false;
  isProcessing.value = false;
}

const toggleSupportWidgetVisibility = () => {
  if (window.$chatwoot) {
    window.$chatwoot.toggleBubbleVisibility('show');
  }
};

const setupListenerForWidgetEvent = () => {
  window.addEventListener('chatwoot:on-message', () => {
    toggleSupportWidgetVisibility();
  });
};

onMounted(() => {
  toggleSupportWidgetVisibility();
  setupListenerForWidgetEvent();
});
</script>

<template>
  <div
    class="items-center bg-n-slate-2 flex flex-col justify-center h-full w-full"
  >
    <EmptyState
      :title="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.TITLE')"
      :message="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.PAYMENT_MESSAGE')"
    />
    <div class="mt-6 text-center">
      <button
        :disabled="isProcessing"
        class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl text-base font-semibold text-white cursor-pointer border-none transition-all duration-200 shadow-lg"
        :class="
          buttonError
            ? 'bg-red-500 shadow-red-500/30'
            : 'bg-gradient-to-r from-indigo-500 to-purple-500 shadow-indigo-500/40 hover:-translate-y-0.5 hover:shadow-xl hover:shadow-indigo-500/50 active:translate-y-0 disabled:opacity-60 disabled:cursor-not-allowed disabled:translate-y-0'
        "
        @click="goToCheckout"
      >
        <span v-if="buttonLabel">{{ buttonLabel }}</span>
        <span v-else>💳 {{ $t('APP_GLOBAL.ACCOUNT_SUSPENDED.PAYMENT_BUTTON') }}</span>
      </button>
    </div>
  </div>
</template>
