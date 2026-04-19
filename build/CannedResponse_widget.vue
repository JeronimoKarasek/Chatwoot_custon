<script>
import { mapGetters } from 'vuex';
import { emitter } from 'shared/helpers/mitt';
import MentionBox from '../mentions/MentionBox.vue';

export default {
  components: { MentionBox },
  props: {
    searchKey: {
      type: String,
      default: '',
    },
  },
  emits: ['replace'],
  computed: {
    ...mapGetters({
      cannedMessages: 'getCannedResponses',
    }),
    items() {
      return this.cannedMessages.map(cannedMessage => ({
        label: cannedMessage.short_code,
        key: cannedMessage.short_code,
        description: cannedMessage.response_type === 'audio'
          ? '🎤 ' + (cannedMessage.personal ? '(Pessoal) ' : '') + 'Resposta de áudio'
          : cannedMessage.content,
        responseType: cannedMessage.response_type || 'text',
        audioUrl: cannedMessage.audio_url || null,
        id: cannedMessage.id,
        personal: cannedMessage.personal || false,
      }));
    },
  },
  watch: {
    searchKey() {
      this.fetchCannedResponses();
    },
  },
  mounted() {
    this.fetchCannedResponses();
  },
  methods: {
    fetchCannedResponses() {
      this.$store.dispatch('getCannedResponse', { searchKey: this.searchKey });
    },
    handleMentionClick(item = {}) {
      if (item.responseType === 'audio' && item.audioUrl) {
        // Emit replace with empty to close canned menu and clear the /trigger
        this.$emit('replace', '');
        // Use bus event so ReplyBox can directly handle audio send
        emitter.emit('SEND_AUDIO_CANNED_RESPONSE', {
          audioUrl: item.audioUrl,
          shortCode: item.label,
          id: item.id,
        });
      } else {
        this.$emit('replace', item.description);
      }
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <MentionBox
    v-if="items.length"
    :items="items"
    @mention-select="handleMentionClick"
  />
</template>
