<script setup>
import { computed, onMounted, ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useAccount } from 'dashboard/composables/useAccount';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';

const { accountId } = useAccount();
const uiFlags = useMapGetter('accounts/getUIFlags');

// State
const isLoading = ref(true);
const isUpdating = ref(false);
const agentsAllowed = ref(0);
const agentsUsed = ref(0);
const inboxesAllowed = ref(0);
const inboxesUsed = ref(0);
const newAgents = ref(0);
const newInboxes = ref(0);
const feedbackMessage = ref('');
const feedbackType = ref('');

// Computed
const hasChanges = computed(
  () =>
    newAgents.value !== agentsAllowed.value ||
    newInboxes.value !== inboxesAllowed.value
);

const agentsPct = computed(() =>
  newAgents.value > 0
    ? Math.min((agentsUsed.value / newAgents.value) * 100, 100)
    : 0
);

const inboxesPct = computed(() =>
  newInboxes.value > 0
    ? Math.min((inboxesUsed.value / newInboxes.value) * 100, 100)
    : 0
);

const totalMonthly = computed(
  () => newAgents.value * 29 + newInboxes.value * 49.9
);

const totalFormatted = computed(
  () => 'R$ ' + totalMonthly.value.toFixed(2).replace('.', ',')
);

// Auth helpers
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

// API calls
async function fetchLimits() {
  try {
    const r = await fetch(
      `/enterprise/api/v1/accounts/${accountId.value}/limits`,
      { headers: getAuthHeaders(), credentials: 'same-origin' }
    );
    const d = await r.json();
    if (d && d.limits) {
      const ag = d.limits.agents || {};
      const ib = d.limits.inboxes || {};
      agentsAllowed.value = ag.allowed || 0;
      agentsUsed.value = ag.consumed || 0;
      inboxesAllowed.value = ib.allowed || 0;
      inboxesUsed.value = ib.consumed || 0;
      newAgents.value = agentsAllowed.value;
      newInboxes.value = inboxesAllowed.value;
    }
  } catch (e) {
    // silent
  }
  isLoading.value = false;
}

async function saveChanges() {
  if (!hasChanges.value || isUpdating.value) return;
  isUpdating.value = true;
  feedbackMessage.value = '';
  try {
    const r = await fetch(
      `/enterprise/api/v1/accounts/${accountId.value}/update_quantities`,
      {
        method: 'POST',
        headers: getAuthHeaders(),
        credentials: 'same-origin',
        body: JSON.stringify({
          agents: newAgents.value,
          inboxes: newInboxes.value,
        }),
      }
    );
    const d = await r.json();
    if (r.ok && d.success) {
      agentsAllowed.value = d.agents?.allowed ?? newAgents.value;
      agentsUsed.value = d.agents?.consumed ?? agentsUsed.value;
      inboxesAllowed.value = d.inboxes?.allowed ?? newInboxes.value;
      inboxesUsed.value = d.inboxes?.consumed ?? inboxesUsed.value;
      newAgents.value = agentsAllowed.value;
      newInboxes.value = inboxesAllowed.value;
      showFeedback(
        d.message || 'Alterações salvas com sucesso!',
        'success'
      );
      if (d.invoice_url) {
        setTimeout(
          () =>
            showFeedback(
              'Nova fatura gerada. Clique em "Ir para Pagamento" para pagar.',
              'warning'
            ),
          3000
        );
      }
    } else {
      showFeedback(d.error || 'Erro ao salvar alterações.', 'error');
    }
  } catch (e) {
    showFeedback('Erro de conexão: ' + e.message, 'error');
  }
  isUpdating.value = false;
}

async function goToCheckout() {
  try {
    const r = await fetch(
      `/enterprise/api/v1/accounts/${accountId.value}/checkout`,
      {
        method: 'POST',
        headers: getAuthHeaders(),
        credentials: 'same-origin',
      }
    );
    const d = await r.json();
    if (d.redirect_url) {
      window.open(d.redirect_url, '_blank');
    } else if (d.error) {
      showFeedback(d.error, 'error');
    }
  } catch (e) {
    showFeedback('Erro ao abrir portal de pagamento.', 'error');
  }
}

function showFeedback(msg, type) {
  feedbackMessage.value = msg;
  feedbackType.value = type;
  if (type !== 'error') {
    setTimeout(() => {
      feedbackMessage.value = '';
    }, 5000);
  }
}

function barColor(pct) {
  if (pct >= 90) return '#ef4444';
  if (pct >= 70) return '#f59e0b';
  return '#10b981';
}

function decrAgents() {
  const min = Math.max(agentsUsed.value, 1);
  if (newAgents.value > min) {
    newAgents.value--;
  } else {
    showFeedback(
      'Mínimo atingido.' +
        (agentsUsed.value > 1 ? ' Remova agentes primeiro.' : ''),
      'warning'
    );
  }
}

function decrInboxes() {
  const min = Math.max(inboxesUsed.value, 1);
  if (newInboxes.value > min) {
    newInboxes.value--;
  } else {
    showFeedback(
      'Mínimo atingido.' +
        (inboxesUsed.value > 1
          ? ' Remova caixas de entrada primeiro.'
          : ''),
      'warning'
    );
  }
}

function resetChanges() {
  newAgents.value = agentsAllowed.value;
  newInboxes.value = inboxesAllowed.value;
  showFeedback('Alterações desfeitas.', 'success');
}

onMounted(fetchLimits);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading || uiFlags.isFetchingItem"
    :loading-message="$t('BILLING_SETTINGS.NO_BILLING_USER')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('BILLING_SETTINGS.TITLE')"
        :description="$t('BILLING_SETTINGS.DESCRIPTION')"
        feature-name="billing"
      />
    </template>
    <template #body>
      <section class="space-y-6">
        <!-- Subscription Management Panel -->
        <div
          class="rounded-2xl border border-n-weak bg-n-solid-2 p-6 space-y-6"
        >
          <div>
            <h3 class="text-lg font-bold flex items-center gap-2 mb-1">
              {{ $t('BILLING_SETTINGS.FAROLCHAT.MANAGE_TITLE') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ $t('BILLING_SETTINGS.FAROLCHAT.MANAGE_DESCRIPTION') }}
            </p>
          </div>

          <!-- Quantity Cards Grid -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <!-- Agents Card -->
            <div
              class="rounded-xl border p-5 space-y-3 transition-shadow hover:shadow-md bg-n-solid-1"
              :class="
                newAgents !== agentsAllowed
                  ? 'border-woot-500 ring-2 ring-woot-500/20'
                  : 'border-n-weak'
              "
            >
              <div class="text-3xl">👤</div>
              <div
                class="text-xs font-bold uppercase tracking-wider text-n-slate-11"
              >
                {{ $t('BILLING_SETTINGS.FAROLCHAT.AGENTS_LABEL') }}
              </div>
              <div class="flex items-center gap-3">
                <button
                  class="size-9 rounded-lg border border-n-weak bg-n-solid-2 text-xl font-semibold flex items-center justify-center cursor-pointer hover:border-woot-500 hover:text-woot-500 active:scale-[0.92] transition-all select-none"
                  @click="decrAgents"
                >
                  −
                </button>
                <div class="text-3xl font-extrabold min-w-[48px] text-center">
                  {{ newAgents }}
                </div>
                <button
                  class="size-9 rounded-lg border border-n-weak bg-n-solid-2 text-xl font-semibold flex items-center justify-center cursor-pointer hover:border-woot-500 hover:text-woot-500 active:scale-[0.92] transition-all select-none"
                  @click="newAgents++"
                >
                  +
                </button>
              </div>
              <div class="text-xs text-n-slate-11">
                <strong>{{ agentsUsed }}</strong>
                {{ $t('BILLING_SETTINGS.FAROLCHAT.IN_USE_OF') }}
                <strong>{{ newAgents }}</strong>
                {{ $t('BILLING_SETTINGS.FAROLCHAT.RELEASED') }}
              </div>
              <div
                class="h-1.5 bg-n-background rounded-full overflow-hidden"
              >
                <div
                  class="h-full rounded-full transition-all duration-300"
                  :style="{
                    width: agentsPct + '%',
                    backgroundColor: barColor(agentsPct),
                  }"
                />
              </div>
              <div class="text-[11px] text-n-slate-10">
                {{ $t('BILLING_SETTINGS.FAROLCHAT.AGENT_PRICE') }}
              </div>
            </div>

            <!-- Inboxes Card -->
            <div
              class="rounded-xl border p-5 space-y-3 transition-shadow hover:shadow-md bg-n-solid-1"
              :class="
                newInboxes !== inboxesAllowed
                  ? 'border-woot-500 ring-2 ring-woot-500/20'
                  : 'border-n-weak'
              "
            >
              <div class="text-3xl">📱</div>
              <div
                class="text-xs font-bold uppercase tracking-wider text-n-slate-11"
              >
                {{ $t('BILLING_SETTINGS.FAROLCHAT.INBOXES_LABEL') }}
              </div>
              <div class="flex items-center gap-3">
                <button
                  class="size-9 rounded-lg border border-n-weak bg-n-solid-2 text-xl font-semibold flex items-center justify-center cursor-pointer hover:border-woot-500 hover:text-woot-500 active:scale-[0.92] transition-all select-none"
                  @click="decrInboxes"
                >
                  −
                </button>
                <div class="text-3xl font-extrabold min-w-[48px] text-center">
                  {{ newInboxes }}
                </div>
                <button
                  class="size-9 rounded-lg border border-n-weak bg-n-solid-2 text-xl font-semibold flex items-center justify-center cursor-pointer hover:border-woot-500 hover:text-woot-500 active:scale-[0.92] transition-all select-none"
                  @click="newInboxes++"
                >
                  +
                </button>
              </div>
              <div class="text-xs text-n-slate-11">
                <strong>{{ inboxesUsed }}</strong>
                {{ $t('BILLING_SETTINGS.FAROLCHAT.IN_USE_OF') }}
                <strong>{{ newInboxes }}</strong>
                {{ $t('BILLING_SETTINGS.FAROLCHAT.RELEASED_F') }}
              </div>
              <div
                class="h-1.5 bg-n-background rounded-full overflow-hidden"
              >
                <div
                  class="h-full rounded-full transition-all duration-300"
                  :style="{
                    width: inboxesPct + '%',
                    backgroundColor: barColor(inboxesPct),
                  }"
                />
              </div>
              <div class="text-[11px] text-n-slate-10">
                {{ $t('BILLING_SETTINGS.FAROLCHAT.INBOX_PRICE') }}
              </div>
            </div>
          </div>

          <!-- Total -->
          <div
            class="flex justify-between items-center px-4 py-3 bg-n-background rounded-lg"
          >
            <span class="text-sm">
              {{ $t('BILLING_SETTINGS.FAROLCHAT.MONTHLY_TOTAL') }}
            </span>
            <span class="text-xl font-bold text-woot-500">
              {{ totalFormatted }}
            </span>
          </div>

          <!-- Actions -->
          <div class="flex gap-3 flex-wrap items-center">
            <ButtonV4
              sm
              solid
              blue
              :disabled="!hasChanges || isUpdating"
              @click="saveChanges"
            >
              {{
                isUpdating
                  ? $t('BILLING_SETTINGS.FAROLCHAT.SAVING')
                  : $t('BILLING_SETTINGS.FAROLCHAT.SAVE_CHANGES')
              }}
            </ButtonV4>
            <ButtonV4 sm solid slate @click="goToCheckout">
              {{ $t('BILLING_SETTINGS.FAROLCHAT.GO_TO_PAYMENT') }}
            </ButtonV4>
            <ButtonV4
              v-if="hasChanges"
              sm
              flushed
              slate
              @click="resetChanges"
            >
              {{ $t('BILLING_SETTINGS.FAROLCHAT.UNDO') }}
            </ButtonV4>
          </div>

          <!-- Feedback -->
          <div
            v-if="feedbackMessage"
            class="p-3 rounded-lg text-sm font-medium border transition-all"
            :class="{
              'bg-green-50 text-green-800 border-green-200 dark:bg-green-900/30 dark:text-green-300 dark:border-green-800':
                feedbackType === 'success',
              'bg-red-50 text-red-800 border-red-200 dark:bg-red-900/30 dark:text-red-300 dark:border-red-800':
                feedbackType === 'error',
              'bg-yellow-50 text-yellow-800 border-yellow-200 dark:bg-yellow-900/30 dark:text-yellow-300 dark:border-yellow-800':
                feedbackType === 'warning',
            }"
          >
            {{ feedbackMessage }}
          </div>
        </div>
      </section>
    </template>
  </SettingsLayout>
</template>
