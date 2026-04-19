<script>
/* eslint no-console: 0 */
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { convertToMp3 } from 'dashboard/components/widgets/WootWriter/utils/mp3ConversionUtils';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    id: { type: Number, default: null },
    edcontent: { type: String, default: '' },
    edshortCode: { type: String, default: '' },
    edresponseType: { type: String, default: 'text' },
    edpersonal: { type: Boolean, default: false },
    edaudioUrl: { type: String, default: '' },
    onClose: { type: Function, default: () => {} },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      editCanned: {
        showAlert: false,
        showLoading: false,
      },
      shortCode: this.edshortCode,
      content: this.edcontent,
      responseType: this.edresponseType || 'text',
      show: true,
      // Audio
      isRecording: false,
      hasNewRecording: false,
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
    pageTitle() {
      return `${this.$t('CANNED_MGMT.EDIT.TITLE')} - ${this.edshortCode}`;
    },
    isAudioMode() {
      return this.responseType === 'audio';
    },
    hasExistingAudio() {
      return this.isAudioMode && this.edaudioUrl;
    },
    isFormValid() {
      if (this.isAudioMode) {
        return this.shortCode.length >= 2 && (this.hasNewRecording || this.hasExistingAudio);
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
      this.hasNewRecording = false;
      this.isPlaying = false;
      this.audioBlob = null;
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
          try {
            this.audioBlob = await convertToMp3(webmBlob);
          } catch {
            this.audioBlob = webmBlob;
          }
          this.audioFileName = `canned_audio_${Date.now()}.mp3`;
          this.audioUrl = URL.createObjectURL(webmBlob);
          this.hasNewRecording = true;
          this.isRecording = false;
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
    playAudio(url) {
      const playUrl = url || this.audioUrl || this.edaudioUrl;
      if (!playUrl) return;
      if (this.isPlaying && this.audioElement) {
        this.audioElement.pause();
        this.isPlaying = false;
        return;
      }
      this.audioElement = new Audio(playUrl);
      this.audioElement.onended = () => {
        this.isPlaying = false;
      };
      this.audioElement.play();
      this.isPlaying = true;
    },
    reRecord() {
      this.cleanupAudio();
    },
    editCannedResponse() {
      this.editCanned.showLoading = true;
      if (this.isAudioMode && this.hasNewRecording) {
        this.$store
          .dispatch('updateCannedResponseWithAudio', {
            id: this.id,
            shortCode: this.shortCode,
            audioBlob: this.audioBlob,
            audioFileName: this.audioFileName,
          })
          .then(() => {
            this.editCanned.showLoading = false;
            useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
            this.resetForm();
            setTimeout(() => { this.onClose(); }, 10);
          })
          .catch(error => {
            this.editCanned.showLoading = false;
            const errorMessage = error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
            useAlert(errorMessage);
          });
      } else if (this.isAudioMode) {
        // Audio mode but no new recording - just update shortcode
        this.$store
          .dispatch('updateCannedResponse', {
            id: this.id,
            short_code: this.shortCode,
          })
          .then(() => {
            this.editCanned.showLoading = false;
            useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
            this.resetForm();
            setTimeout(() => { this.onClose(); }, 10);
          })
          .catch(error => {
            this.editCanned.showLoading = false;
            const errorMessage = error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
            useAlert(errorMessage);
          });
      } else {
        this.$store
          .dispatch('updateCannedResponse', {
            id: this.id,
            short_code: this.shortCode,
            content: this.content,
          })
          .then(() => {
            this.editCanned.showLoading = false;
            useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
            this.resetForm();
            setTimeout(() => { this.onClose(); }, 10);
          })
          .catch(error => {
            this.editCanned.showLoading = false;
            const errorMessage = error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
            useAlert(errorMessage);
          });
      }
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="pageTitle" />
      <form class="flex flex-col w-full" @submit.prevent="editCannedResponse()">
        <!-- Short Code -->
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.PLACEHOLDER')"
              @input="v$.shortCode.$touch"
            />
          </label>
        </div>

        <!-- Audio Mode - Existing Audio -->
        <div v-if="isAudioMode" class="w-full mb-4">
          <label class="text-sm font-medium text-n-slate-12 block mb-2">
            {{ $t('CANNED_MGMT.AUDIO.LABEL') }}
          </label>

          <!-- Has existing audio and no new recording -->
          <div
            v-if="hasExistingAudio && !hasNewRecording && !isRecording"
            class="flex flex-col items-center gap-3 p-6 bg-n-slate-1 border border-n-slate-4 rounded-xl"
          >
            <p class="text-sm text-n-slate-11">
              {{ $t('CANNED_MGMT.AUDIO.EXISTING') }}
            </p>
            <div class="flex gap-2">
              <NextButton
                type="button"
                :label="isPlaying ? $t('CANNED_MGMT.AUDIO.PAUSE') : $t('CANNED_MGMT.AUDIO.PLAY')"
                size="sm"
                faded
                @click="playAudio(edaudioUrl)"
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

          <!-- No existing audio and not recording -->
          <div
            v-if="!hasExistingAudio && !hasNewRecording && !isRecording"
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

          <!-- New recording - Preview -->
          <div
            v-if="hasNewRecording && !isRecording"
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
                @click="playAudio()"
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

        <!-- Text Content (shown for text mode) -->
        <div v-if="!isAudioMode" class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: v$.content.$error }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
            :disabled="!isFormValid || editCanned.showLoading"
            :is-loading="editCanned.showLoading"
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
