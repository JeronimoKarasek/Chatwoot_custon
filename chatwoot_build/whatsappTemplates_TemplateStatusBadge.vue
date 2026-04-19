<script setup>
defineProps({
  status: {
    type: String,
    required: true,
  },
});

const statusConfig = {
  APPROVED: {
    label: 'Aprovado',
    class: 'bg-n-teal-3 text-n-teal-11',
    icon: 'i-lucide-check-circle',
  },
  PENDING: {
    label: 'Pendente',
    class: 'bg-n-amber-3 text-n-amber-11',
    icon: 'i-lucide-clock',
  },
  REJECTED: {
    label: 'Rejeitado',
    class: 'bg-n-ruby-3 text-n-ruby-11',
    icon: 'i-lucide-x-circle',
  },
  PAUSED: {
    label: 'Pausado',
    class: 'bg-n-orange-3 text-n-orange-11',
    icon: 'i-lucide-pause-circle',
  },
  DISABLED: {
    label: 'Desabilitado',
    class: 'bg-n-slate-3 text-n-slate-11',
    icon: 'i-lucide-ban',
  },
  IN_APPEAL: {
    label: 'Em Recurso',
    class: 'bg-n-blue-3 text-n-blue-11',
    icon: 'i-lucide-alert-circle',
  },
  PENDING_DELETION: {
    label: 'Exclusão Pendente',
    class: 'bg-n-slate-3 text-n-slate-11',
    icon: 'i-lucide-trash',
  },
};

function getConfig(status) {
  return (
    statusConfig[status] || {
      label: status,
      class: 'bg-n-slate-3 text-n-slate-11',
      icon: 'i-lucide-help-circle',
    }
  );
}
</script>

<template>
  <span
    class="inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium"
    :class="getConfig(status).class"
  >
    <span :class="getConfig(status).icon" class="text-xs" />
    {{ getConfig(status).label }}
  </span>
</template>
