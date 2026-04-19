<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { convertToMp3 } from 'dashboard/components/widgets/WootWriter/utils/mp3ConversionUtils';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  name: 'AddCanned',
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    onClose: {
      type: Function,
      default: () => {},
    },
    defaultPersonal: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      shortCode: '',
      content: this.responseContent || '',
      responseType: 'text',
      isPersonal: this.defaultPersonal,
      addCanned: {
        showLoading: false,
        message: '',
      },
      show: true,
      // Audio recording
      isRecording: false,
      hasRecording: false,
      isPlaying: false,
      audioBlob: null,
      audioFileName: '',
      audioUrl: null,
      recordingTime: '00:00',
      mediaRecorder: null,
      audioChunks: [],
      recordingInterval: null,
      recordingStartTime: null,
      audioElement: null,
    };
  },
  validations: {
    shortCode: {
      required,
      minLength: minLength(2),
    },
    content: {
      required,
    },
  },
  computed: {
    isAudioMode() {
      return this.responseType === 'audio';
    },
    isFormValid() {
      if (this.isAudioMode) {
        return this.shortCode.length >= 2 && this.hasRecording;
      }
      return !this.v$.content.$invalid && !this.v$.shortCode.$invalid;
    },
  },
  beforeUnmount() {
    this.cleanupAudio();
  },
  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.responseType = 'text';
      this.isPersonal = this.defaultPersonal;
      this.cleanupAudio();
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    cleanupAudio() {
      if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
        this.mediaRecorder.stop();
      }
      if (this.recordingInterval) {
        clearInterval(this.recordingInterval);
      }
      if (this.audioUrl) {
        URL.revokeObjectURL(this.audioUrl);
      }
      if (this.audioElement) {
        this.audioElement.pause();
        this.audioElement = null;
      }
      this.isRecording = false;
      this.hasRecording = false;
      this.isPlaying = false;
      this.audioBlob = null;
      this.audioFileName = '';
      this.audioUrl = null;
      this.recordingTime = '00:00';
      this.audioChunks = [];
    },
    async startRecording() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        this.audioChunks = [];
        this.mediaRecorder = new MediaRecorder(stream, {
          mimeType: MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
            ? 'audio/webm;codecs=opus'
            : 'audio/webm',
        });

        this.mediaRecorder.ondataavailable = (event) => {
          if (event.data.size > 0) {
            this.audioChunks.push(event.data);
          }
        };

        this.mediaRecorder.onstop = async () => {
          const webmBlob = new Blob(this.audioChunks, { type: 'audio/webm' });
          // Convert webm to real MP3 for WhatsApp compatibility
          try {
            this.audioBlob = await convertToMp3(webmBlob);
          } catch {
            // Fallback: send webm as-is if conversion fails
            this.audioBlob = webmBlob;
          }
          this.audioFileName = `canned_audio_${Date.now()}.mp3`;
          this.audioUrl = URL.createObjectURL(webmBlob);
          this.hasRecording = true;
          this.isRecording = false;

          // Stop all tracks
          stream.getTracks().forEach(track => track.stop());
        };

        this.mediaRecorder.start(100);
        this.isRecording = true;
        this.recordingStartTime = Date.now();

        this.recordingInterval = setInterval(() => {
          const elapsed = Date.now() - this.recordingStartTime;
          const seconds = Math.floor(elapsed / 1000);
          const mins = Math.floor(seconds / 60);
          const secs = seconds % 60;
          this.recordingTime = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        }, 200);
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.AUDIO.MIC_ERROR'));
      }
    },
    stopRecording() {
      if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
        this.mediaRecorder.stop();
      }
      if (this.recordingInterval) {
        clearInterval(this.recordingInterval);
        this.recordingInterval = null;
      }
    },
    playAudio() {
      if (!this.audioUrl) return;
      if (this.isPlaying && this.audioElement) {
        this.audioElement.pause();
        this.isPlaying = false;
        return;
      }
      this.audioElement = new Audio(this.audioUrl);
      this.audioElement.onended = () => {
        this.isPlaying = false;
      };
      this.audioElement.play();
      this.isPlaying = true;
    },
    reRecord() {
      this.cleanupAudio();
    },
    async addCannedResponse() {
      this.addCanned.showLoading = true;
      try {
        if (this.isAudioMode) {
          await this.$store.dispatch('createCannedResponseWithAudio', {
            shortCode: this.shortCode,
            audioBlob: this.audioBlob,
            audioFileName: this.audioFileName,
          });
        } else {
          const payload = {
            short_code: this.shortCode,
            content: this.content,
          };
          if (this.isPersonal) {
            payload.personal = true;
          }
          await this.$store.dispatch('createCannedResponse', payload);
        }
        this.addCanned.showLoading = false;
        useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
        this.resetForm();
        this.onClose();
      } catch (error) {
        this.addCanned.showLoading = false;
        const errorMessage =
          error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CANNED_MGMT.ADD.TITLE')"
        :header-content="$t('CANNED_MGMT.ADD.DESC')"
      />
      <form class="flex flex-col w-full" @submit.prevent="addCannedResponse()">
        <!-- Short Code -->
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              @blur="v$.shortCode.$touch"
            />
          </label>
        </div>

        <!-- Personal Toggle -->
        <div class="w-full mb-3">
          <label class="flex items-center gap-3 cursor-pointer select-none">
            <input
              v-model="isPersonal"
              type="checkbox"
              class="w-4 h-4 rounded border-n-slate-6 text-n-brand focus:ring-n-brand"
            />
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('CANNED_MGMT.ADD.FORM.PERSONAL.LABEL') }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{ $t('CANNED_MGMT.ADD.FORM.PERSONAL.HELP') }}
            </span>
          </label>
        </div>

        <!-- Response Type Toggle (only for personal) -->
        <div v-if="isPersonal" class="w-full mb-3">
          <label class="text-sm font-medium text-n-slate-12 block mb-2">
            {{ $t('CANNED_MGMT.ADD.FORM.RESPONSE_TYPE.LABEL') }}
          </label>
          <div class="flex gap-2">
            <button
              type="button"
              class="px-4 py-2 text-sm font-medium rounded-lg transition-colors"
              :class="responseType === 'text'
                ? 'bg-n-brand text-white'
                : 'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3'"
              @click="responseType = 'text'; cleanupAudio()"
            >
              ✏️ {{ $t('CANNED_MGMT.ADD.FORM.RESPONSE_TYPE.TEXT') }}
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm font-medium rounded-lg transition-colors"
              :class="responseType === 'audio'
                ? 'bg-n-brand text-white'
                : 'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3'"
              @click="responseType = 'audio'"
            >
              🎤 {{ $t('CANNED_MGMT.ADD.FORM.RESPONSE_TYPE.AUDIO') }}
            </button>
          </div>
        </div>

        <!-- Text Content (shown for text mode) -->
        <div v-if="!isAudioMode" class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: v$.content.$error }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <!-- Audio Recorder (shown for audio mode) -->
        <div v-if="isAudioMode" class="w-full mb-4">
          <label class="text-sm font-medium text-n-slate-12 block mb-2">
            {{ $t('CANNED_MGMT.AUDIO.LABEL') }}
          </label>

          <!-- Not yet recorded -->
          <div
            v-if="!hasRecording && !isRecording"
            class="flex flex-col items-center gap-3 p-6 border-2 border-dashed border-n-slate-4 rounded-xl"
          >
            <div class="text-4xl">🎙️</div>
            <p class="text-sm text-n-slate-11">
              {{ $t('CANNED_MGMT.AUDIO.CLICK_TO_RECORD') }}
            </p>
            <NextButton
              type="button"
              :label="$t('CANNED_MGMT.AUDIO.START')"
              size="sm"
              @click="startRecording"
            />
          </div>

          <!-- Recording in progress -->
          <div
            v-if="isRecording"
            class="flex flex-col items-center gap-3 p-6 bg-n-ruby-1 border border-n-ruby-6 rounded-xl"
          >
            <div class="flex items-center gap-2">
              <span class="w-3 h-3 bg-n-ruby-9 rounded-full animate-pulse" />
              <span class="text-lg font-mono font-bold text-n-ruby-11">
                {{ recordingTime }}
              </span>
            </div>
            <p class="text-sm text-n-ruby-11">
              {{ $t('CANNED_MGMT.AUDIO.RECORDING') }}
            </p>
            <NextButton
              type="button"
              :label="$t('CANNED_MGMT.AUDIO.STOP')"
              size="sm"
              class="bg-n-ruby-9 hover:bg-n-ruby-10 text-white"
              @click="stopRecording"
            />
          </div>

          <!-- Recorded - Preview -->
          <div
            v-if="hasRecording && !isRecording"
            class="flex flex-col items-center gap-3 p-6 bg-n-teal-1 border border-n-teal-6 rounded-xl"
          >
            <div class="text-3xl">✅</div>
            <p class="text-sm font-medium text-n-teal-11">
              {{ $t('CANNED_MGMT.AUDIO.RECORDED') }}
            </p>
            <div class="flex gap-2">
              <NextButton
                type="button"
                :label="isPlaying ? $t('CANNED_MGMT.AUDIO.PAUSE') : $t('CANNED_MGMT.AUDIO.PLAY')"
                size="sm"
                faded
                @click="playAudio"
              />
              <NextButton
                type="button"
                :label="$t('CANNED_MGMT.AUDIO.RERECORD')"
                size="sm"
                faded
                slate
                @click="reRecord"
              />
            </div>
          </div>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
            :disabled="!isFormValid || addCanned.showLoading"
            :is-loading="addCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
::v-deep {
  .ProseMirror-menubar {
    @apply hidden;
  }

  .reply-editor--note {
    &.reply-editor {
      @apply p-0;
    }
  }

  .reply-editor {
    @apply border rounded-md border-solid border-n-weak p-0;
    min-height: 12rem;
  }
}

.editor_warning {
  @apply border border-n-ruby-5;
}
</style>
