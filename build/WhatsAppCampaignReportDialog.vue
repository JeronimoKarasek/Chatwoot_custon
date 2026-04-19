<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import CampaignsAPI from 'dashboard/api/campaigns';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  campaign: { type: Object, required: true },
});

const emit = defineEmits(['close']);

const dialogRef = ref(null);
const isLoading = ref(true);
const reportData = ref(null);
const filterStatus = ref('all');

onMounted(async () => {
  dialogRef.value?.open();
  try {
    const response = await CampaignsAPI.getReport(props.campaign.id);
    reportData.value = response.data;
  } catch (e) {
    useAlert('Erro ao carregar relatório');
  } finally {
    isLoading.value = false;
  }
});

const handleClose = () => {
  dialogRef.value?.close();
  emit('close');
};

const logs = computed(() => {
  if (!reportData.value?.send_logs) return [];
  return reportData.value.send_logs;
});

const filteredLogs = computed(() => {
  if (filterStatus.value === 'all') return logs.value;
  return logs.value.filter(l => l.status === filterStatus.value);
});

const sentCount = computed(() => reportData.value?.sent || 0);
const failedCount = computed(() => reportData.value?.failed || 0);
const totalCount = computed(() => reportData.value?.total || 0);

const statusLabel = computed(() => {
  const s = reportData.value?.status;
  if (s === 'completed') return 'Concluída';
  if (s === 'running') return 'Em execução';
  if (s === 'failed') return 'Falhou';
  return 'Pendente';
});

const formatTime = dateStr => {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
};

const downloadCsv = () => {
  if (!logs.value.length) return;
  const header = 'Nome,Telefone,Status,Erro,Horário\n';
  const rows = logs.value.map(l =>
    `"${l.name}","${l.phone}","${l.status === 'sent' ? 'Enviado' : 'Falhou'}","${(l.error || '').replace(/"/g, '""')}","${formatTime(l.at)}"`
  ).join('\n');
  const blob = new Blob([header + rows], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `relatorio_campanha_${props.campaign.id}.csv`;
  a.click();
  URL.revokeObjectURL(url);
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    title="Relatório de Envio"
    width="3xl"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="handleClose"
  >
    <div class="flex flex-col gap-4 max-h-[70vh]">
      <!-- Loading -->
      <div v-if="isLoading" class="flex items-center justify-center py-10">
        <Spinner />
      </div>

      <template v-else-if="reportData">
        <!-- Summary cards -->
        <div class="flex gap-3">
          <div class="flex-1 rounded-lg bg-n-alpha-2 p-3 text-center">
            <div class="text-2xl font-bold text-n-slate-12">{{ totalCount }}</div>
            <div class="text-xs text-n-slate-11">Total</div>
          </div>
          <div class="flex-1 rounded-lg bg-n-teal-3 p-3 text-center">
            <div class="text-2xl font-bold text-n-teal-11">{{ sentCount }}</div>
            <div class="text-xs text-n-teal-11">Enviadas</div>
          </div>
          <div class="flex-1 rounded-lg bg-n-ruby-3 p-3 text-center">
            <div class="text-2xl font-bold text-n-ruby-11">{{ failedCount }}</div>
            <div class="text-xs text-n-ruby-11">Falhas</div>
          </div>
          <div class="flex-1 rounded-lg bg-n-alpha-2 p-3 text-center">
            <div class="text-sm font-bold text-n-slate-12">{{ statusLabel }}</div>
            <div class="text-xs text-n-slate-11">Status</div>
          </div>
        </div>

        <!-- Filter + Download -->
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <button
              class="text-xs px-2 py-1 rounded-md transition-colors"
              :class="filterStatus === 'all' ? 'bg-n-blue-9 text-white' : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3'"
              @click="filterStatus = 'all'"
            >
              Todos ({{ logs.length }})
            </button>
            <button
              class="text-xs px-2 py-1 rounded-md transition-colors"
              :class="filterStatus === 'sent' ? 'bg-n-teal-9 text-white' : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3'"
              @click="filterStatus = 'sent'"
            >
              ✅ Enviados
            </button>
            <button
              class="text-xs px-2 py-1 rounded-md transition-colors"
              :class="filterStatus === 'failed' ? 'bg-n-ruby-9 text-white' : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3'"
              @click="filterStatus = 'failed'"
            >
              ❌ Falhas
            </button>
          </div>
          <Button
            size="xs"
            variant="faded"
            icon="i-lucide-download"
            label="CSV"
            @click="downloadCsv"
          />
        </div>

        <!-- Logs table -->
        <div class="overflow-auto max-h-[45vh] rounded-lg border border-n-container">
          <table v-if="filteredLogs.length > 0" class="w-full text-sm">
            <thead class="sticky top-0 bg-n-solid-3">
              <tr class="text-left text-xs text-n-slate-11">
                <th class="px-3 py-2 font-medium">Nome</th>
                <th class="px-3 py-2 font-medium">Telefone</th>
                <th class="px-3 py-2 font-medium">Status</th>
                <th class="px-3 py-2 font-medium">Erro</th>
                <th class="px-3 py-2 font-medium">Horário</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(log, idx) in filteredLogs"
                :key="idx"
                class="border-t border-n-container hover:bg-n-alpha-1"
              >
                <td class="px-3 py-2 text-n-slate-12">{{ log.name }}</td>
                <td class="px-3 py-2 text-n-slate-11 font-mono text-xs">{{ log.phone }}</td>
                <td class="px-3 py-2">
                  <span
                    class="text-xs font-medium px-1.5 py-0.5 rounded"
                    :class="log.status === 'sent' ? 'bg-n-teal-3 text-n-teal-11' : 'bg-n-ruby-3 text-n-ruby-11'"
                  >
                    {{ log.status === 'sent' ? 'Enviado' : 'Falhou' }}
                  </span>
                </td>
                <td class="px-3 py-2 text-xs text-n-ruby-11 max-w-[200px] truncate" :title="log.error">
                  {{ log.error || '-' }}
                </td>
                <td class="px-3 py-2 text-xs text-n-slate-11">{{ formatTime(log.at) }}</td>
              </tr>
            </tbody>
          </table>
          <div v-else class="text-center py-8 text-sm text-n-slate-11">
            Nenhum registro de envio encontrado.
          </div>
        </div>
      </template>

      <!-- No data -->
      <div v-else class="text-center py-8 text-sm text-n-slate-11">
        Nenhum dado disponível.
      </div>
    </div>
  </Dialog>
</template>
