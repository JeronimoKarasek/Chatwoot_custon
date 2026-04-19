<script>
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import InboxName from 'dashboard/components/widgets/InboxName.vue';
import Modal from 'dashboard/components/Modal.vue';
import EvolutionAPI from 'dashboard/api/evolution';
import { BUS_EVENTS } from 'shared/constants/busEvents';

export default {
  components: {
    NextButton,
    SettingsSection,
    InboxName,
    Modal,
  },
  props: {
    inbox: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isLoading: false,
      isDisconnecting: false,
      isGeneratingQR: false,
      qrCode: null,
      showQrModal: false,
      instanceStatus: null,
      proxySettings: {
        enabled: false,
        host: '',
        port: '',
        username: '',
        password: '',
      },
      instanceSettings: {
        rejectCall: true,
        msgCall: 'I do not accept calls',
        groupsIgnore: false,
        alwaysOnline: true,
        readMessages: false,
        syncFullHistory: false,
        readStatus: false,
      },
      // Profile settings
      profileSettings: {
        name: '',
        status: '',
        pictureUrl: '',
      },
      currentProfilePicture: null,
      isLoadingProfile: false,
      isUpdatingProfileName: false,
      isUpdatingProfileStatus: false,
      isUpdatingProfilePicture: false,
    };
  },
  computed: {
    canShowQRCode() {
      return this.instanceStatus !== 'open';
    },
    hasValidProxyConfig() {
      if (!this.proxySettings.enabled) return true;
      return this.proxySettings.host && this.proxySettings.port;
    },
    instanceName() {
      return this.inbox.provider_config?.instance_name || this.inbox.name;
    },
    apiUrl() {
      return this.inbox.provider_config?.api_url;
    },
    apiKey() {
      return this.inbox.provider_config?.admin_token;
    },
  },
  watch: {
    instanceStatus(newStatus) {
      if (newStatus === 'open') {
        this.qrCode = null;
        this.showQrModal = false;
      }
    },
    qrCode(newCode) {
      this.showQrModal = !!newCode;
    },
  },
  created() {
    this.loadSettings();
    this.checkInstanceStatus();
    this.loadInstanceSettings();
    this.loadProfileData();
    emitter.on(BUS_EVENTS.WHATSAPP_QRCODE_UPDATED, this.onQrCodeUpdated);
    emitter.on(BUS_EVENTS.WHATSAPP_CONNECTION_UPDATE, this.onConnectionUpdate);
  },

  unmounted() {
    emitter.off(BUS_EVENTS.WHATSAPP_QRCODE_UPDATED, this.onQrCodeUpdated);
    emitter.off(BUS_EVENTS.WHATSAPP_CONNECTION_UPDATE, this.onConnectionUpdate);
  },
  methods: {
    onQrCodeUpdated(payload) {
      if (payload.inbox_id !== this.inbox.id) return;
      this.qrCode = payload.qr_code;
      this.showQrModal = !!payload.qr_code;
    },

    onConnectionUpdate(payload) {
      if (payload.inbox_id !== this.inbox.id) return;
      this.instanceStatus = payload.status;
      if (this.instanceStatus === 'open') {
        this.qrCode = null;
        this.showQrModal = false;
        // Reload profile when connected
        this.loadProfileData();
      }
    },

    loadSettings() {
      const config = this.inbox.provider_config || {};
      this.proxySettings = {
        enabled: config.proxy_enabled || false,
        host: config.proxy_host || '',
        port: config.proxy_port || '',
        username: config.proxy_username || '',
        password: config.proxy_password || '',
      };
    },

    async updateProxySettings() {
      if (!this.hasValidProxyConfig) {
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROXY.VALIDATION_ERROR'));
        return;
      }

      try {
        this.isLoading = true;

        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider_config: {
              ...this.inbox.provider_config,
              proxy_enabled: this.proxySettings.enabled,
              proxy_host: this.proxySettings.host,
              proxy_port: this.proxySettings.port,
              proxy_username: this.proxySettings.username,
              proxy_password: this.proxySettings.password,
            },
          },
        };

        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROXY.SUCCESS'));
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.PROXY.ERROR')
        );
      } finally {
        this.isLoading = false;
      }
    },

    async disconnectInstance() {
      try {
        this.isDisconnecting = true;

        await EvolutionAPI.logout(
          this.inbox.provider_config.api_url,
          this.inbox.provider_config.admin_token,
          this.inbox.provider_config.instance_name
        );

        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.DISCONNECT.SUCCESS'));
        this.instanceStatus = 'close';
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.DISCONNECT.ERROR')
        );
      } finally {
        this.isDisconnecting = false;
      }
    },

    async checkInstanceStatus() {
      try {
        const instances = await EvolutionAPI.fetchInstances(
          this.inbox.provider_config.api_url,
          this.inbox.provider_config.admin_token
        );

        const instance = instances.find(
          inst => inst.name === this.inbox.provider_config.instance_name
        );

        if (instance) {
          this.instanceStatus = instance.connectionStatus;

          // Clear QR Code when instance is connected
          if (this.instanceStatus === 'open') {
            this.qrCode = null;
          }
        } else {
          this.instanceStatus = 'close';
        }
      } catch (error) {
        // Default to closed state if status cannot be fetched
        this.instanceStatus = 'close';
      }
    },

    async generateQRCode() {
      try {
        this.isGeneratingQR = true;

        const response = await EvolutionAPI.getQRCode(
          this.inbox.provider_config.api_url,
          this.inbox.provider_config.admin_token,
          this.inbox.provider_config.instance_name
        );

        // Try different possible response structures - prioritize base64 images
        this.qrCode =
          response.base64 ||
          response.qrcode?.base64 ||
          response.qrCode ||
          response.qr ||
          response.qrcode?.code ||
          response.code ||
          response;

        if (this.qrCode) {
          this.showQrModal = true;
          useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.QR_CODE.SUCCESS'));
        } else {
          useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.QR_CODE.NO_QR'));
        }
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.QR_CODE.ERROR')
        );
      } finally {
        this.isGeneratingQR = false;
      }
    },

    async refreshStatus() {
      await this.checkInstanceStatus();
      useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.STATUS.REFRESHED'));
    },

    async loadInstanceSettings() {
      try {
        const settings = await EvolutionAPI.findSettings(
          this.inbox.provider_config.api_url,
          this.inbox.provider_config.admin_token,
          this.inbox.provider_config.instance_name
        );

        if (settings) {
          this.instanceSettings = {
            rejectCall: settings.rejectCall ?? true,
            msgCall: settings.msgCall || 'I do not accept calls',
            groupsIgnore: settings.groupsIgnore ?? false,
            alwaysOnline: settings.alwaysOnline ?? true,
            readMessages: settings.readMessages ?? false,
            syncFullHistory: settings.syncFullHistory ?? false,
            readStatus: settings.readStatus ?? false,
          };
        }
      } catch (error) {
        // Silent error handling
      }
    },

    async updateInstanceSettings() {
      try {
        this.isLoading = true;

        await EvolutionAPI.setSettings(
          this.inbox.provider_config.api_url,
          this.inbox.provider_config.admin_token,
          this.inbox.provider_config.instance_name,
          this.instanceSettings
        );

        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.SUCCESS'));
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.ERROR')
        );
      } finally {
        this.isLoading = false;
      }
    },

    // Profile methods
    async loadProfileData() {
      if (!this.apiUrl || !this.apiKey) return;
      
      try {
        this.isLoadingProfile = true;
        
        // Load profile data
        const profile = await EvolutionAPI.fetchProfile(
          this.apiUrl,
          this.apiKey,
          this.instanceName
        );
        
        if (profile) {
          this.profileSettings.name = profile.name || '';
          this.profileSettings.status = profile.status || '';
        }
        
        // Load profile picture
        const pictureUrl = await EvolutionAPI.fetchProfilePicture(
          this.apiUrl,
          this.apiKey,
          this.instanceName
        );
        
        if (pictureUrl) {
          this.currentProfilePicture = pictureUrl;
        }
      } catch (error) {
        // Silent error - profile might not be available
        console.log('Profile load error:', error);
      } finally {
        this.isLoadingProfile = false;
      }
    },

    async updateProfileName() {
      if (!this.profileSettings.name.trim()) {
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.NAME_REQUIRED'));
        return;
      }
      
      try {
        this.isUpdatingProfileName = true;
        
        await EvolutionAPI.updateProfileName(
          this.apiUrl,
          this.apiKey,
          this.instanceName,
          this.profileSettings.name
        );
        
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.NAME_SUCCESS'));
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.NAME_ERROR')
        );
      } finally {
        this.isUpdatingProfileName = false;
      }
    },

    async updateProfileStatus() {
      try {
        this.isUpdatingProfileStatus = true;
        
        await EvolutionAPI.updateProfileStatus(
          this.apiUrl,
          this.apiKey,
          this.instanceName,
          this.profileSettings.status
        );
        
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.STATUS_SUCCESS'));
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.STATUS_ERROR')
        );
      } finally {
        this.isUpdatingProfileStatus = false;
      }
    },

    async updateProfilePicture() {
      if (!this.profileSettings.pictureUrl.trim()) {
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_URL_REQUIRED'));
        return;
      }
      
      try {
        this.isUpdatingProfilePicture = true;
        
        await EvolutionAPI.updateProfilePicture(
          this.apiUrl,
          this.apiKey,
          this.instanceName,
          this.profileSettings.pictureUrl
        );
        
        this.currentProfilePicture = this.profileSettings.pictureUrl;
        this.profileSettings.pictureUrl = '';
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_SUCCESS'));
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_ERROR')
        );
      } finally {
        this.isUpdatingProfilePicture = false;
      }
    },

    async removeProfilePicture() {
      try {
        this.isUpdatingProfilePicture = true;
        
        await EvolutionAPI.removeProfilePicture(
          this.apiUrl,
          this.apiKey,
          this.instanceName
        );
        
        this.currentProfilePicture = null;
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_REMOVED'));
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_REMOVE_ERROR')
        );
      } finally {
        this.isUpdatingProfilePicture = false;
      }
    },
  },
};
</script>

<template>
  <div class="mx-8">
    <!-- Instance Status and Management -->
    <SettingsSection
      :title="$t('INBOX_MGMT.ADD.EVOLUTION.MANAGEMENT.TITLE')"
      :sub-title="$t('INBOX_MGMT.ADD.EVOLUTION.MANAGEMENT.SUBTITLE')"
    >
      <div class="flex flex-col gap-4">
        <InboxName
          :inbox="inbox"
          class="!text-lg !m-0"
          with-phone-number
          with-provider-connection-status
        />

        <div class="flex items-center gap-2">
          <span class="font-medium">{{
            $t('INBOX_MGMT.ADD.EVOLUTION.STATUS.LABEL')
          }}</span>
          <span
            :class="{
              'text-green-600': instanceStatus === 'open',
              'text-yellow-600': instanceStatus === 'connecting',
              'text-red-600': instanceStatus === 'close',
              'text-gray-600': !instanceStatus,
            }"
            class="font-semibold capitalize"
          >
            {{ instanceStatus || 'Unknown' }}
          </span>
          <NextButton
            size="small"
            variant="link"
            :label="$t('INBOX_MGMT.ADD.EVOLUTION.STATUS.REFRESH')"
            @click="refreshStatus"
          />
        </div>

        <div class="flex gap-2">
          <NextButton
            v-if="canShowQRCode"
            :label="$t('INBOX_MGMT.ADD.EVOLUTION.QR_CODE.GENERATE')"
            :is-loading="isGeneratingQR"
            @click="generateQRCode"
          />

          <NextButton
            variant="warning"
            :label="$t('INBOX_MGMT.ADD.EVOLUTION.DISCONNECT.BUTTON')"
            :is-loading="isDisconnecting"
            @click="disconnectInstance"
          />
        </div>

        <Modal
          v-if="qrCode"
          v-model:show="showQrModal"
          :on-close="() => (showQrModal = false)"
        >
          <woot-modal-header
            :header-title="$t('INBOX_MGMT.ADD.EVOLUTION.QR_CODE.TITLE')"
          />
          <div class="p-8 text-center">
            <img
              :src="qrCode"
              alt="WhatsApp QR Code"
              class="max-w-xs mx-auto block"
            />
            <p class="text-sm text-gray-600 mt-2">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.QR_CODE.INSTRUCTIONS') }}
            </p>
          </div>
        </Modal>
      </div>
    </SettingsSection>

    <!-- WhatsApp Profile Settings -->
    <SettingsSection
      v-if="instanceStatus === 'open'"
      :title="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.TITLE')"
      :sub-title="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.SUBTITLE')"
    >
      <div class="space-y-4">
        <!-- Current Profile Picture -->
        <div class="flex items-center gap-4">
          <div class="w-20 h-20 rounded-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center overflow-hidden">
            <img
              v-if="currentProfilePicture"
              :src="currentProfilePicture"
              alt="Profile"
              class="w-full h-full object-cover"
            />
            <span v-else class="text-3xl text-gray-400">👤</span>
          </div>
          <div class="flex-1">
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_URL_HELP') }}
            </p>
          </div>
        </div>

        <!-- Profile Name -->
        <div class="space-y-2">
          <label class="block text-sm font-medium">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.NAME_LABEL') }}
          </label>
          <div class="flex gap-2">
            <input
              v-model="profileSettings.name"
              type="text"
              :placeholder="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.NAME_PLACEHOLDER')"
              class="flex-1"
            />
            <NextButton
              :label="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.UPDATE_NAME')"
              :is-loading="isUpdatingProfileName"
              @click="updateProfileName"
            />
          </div>
        </div>

        <!-- Profile Status -->
        <div class="space-y-2">
          <label class="block text-sm font-medium">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.STATUS_LABEL') }}
          </label>
          <div class="flex gap-2">
            <input
              v-model="profileSettings.status"
              type="text"
              :placeholder="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.STATUS_PLACEHOLDER')"
              class="flex-1"
            />
            <NextButton
              :label="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.UPDATE_STATUS')"
              :is-loading="isUpdatingProfileStatus"
              @click="updateProfileStatus"
            />
          </div>
        </div>

        <!-- Profile Picture URL -->
        <div class="space-y-2">
          <label class="block text-sm font-medium">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_URL_LABEL') }}
          </label>
          <div class="flex gap-2">
            <input
              v-model="profileSettings.pictureUrl"
              type="url"
              :placeholder="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.PICTURE_URL_PLACEHOLDER')"
              class="flex-1"
            />
            <NextButton
              :label="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.UPDATE_PICTURE')"
              :is-loading="isUpdatingProfilePicture"
              @click="updateProfilePicture"
            />
            <NextButton
              v-if="currentProfilePicture"
              variant="warning"
              :label="$t('INBOX_MGMT.ADD.EVOLUTION.PROFILE.REMOVE_PICTURE')"
              :is-loading="isUpdatingProfilePicture"
              @click="removeProfilePicture"
            />
          </div>
        </div>
      </div>
    </SettingsSection>

    <!-- Proxy Settings -->
    <SettingsSection
      :title="$t('INBOX_MGMT.ADD.EVOLUTION.PROXY.TITLE')"
      :sub-title="$t('INBOX_MGMT.ADD.EVOLUTION.PROXY.SUBTITLE')"
    >
      <div class="space-y-4">
        <!-- Enable Proxy Checkbox -->
        <div class="flex items-center gap-2">
          <input
            id="proxyEnabled"
            v-model="proxySettings.enabled"
            type="checkbox"
          />
          <label for="proxyEnabled" class="font-medium">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.ENABLE') }}
          </label>
        </div>

        <!-- Proxy Configuration (shown when enabled) -->
        <div v-if="proxySettings.enabled" class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.HOST') }}
            </label>
            <input
              v-model="proxySettings.host"
              type="text"
              :placeholder="
                $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.HOST_PLACEHOLDER')
              "
              class="w-full"
            />
          </div>

          <div>
            <label class="block text-sm font-medium mb-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.PORT') }}
            </label>
            <input
              v-model="proxySettings.port"
              type="number"
              :placeholder="
                $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.PORT_PLACEHOLDER')
              "
              class="w-full"
            />
          </div>

          <div>
            <label class="block text-sm font-medium mb-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.USERNAME') }}
            </label>
            <input
              v-model="proxySettings.username"
              type="text"
              :placeholder="
                $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.USERNAME_PLACEHOLDER')
              "
              class="w-full"
            />
          </div>

          <div>
            <label class="block text-sm font-medium mb-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.PASSWORD') }}
            </label>
            <input
              v-model="proxySettings.password"
              type="password"
              :placeholder="
                $t('INBOX_MGMT.ADD.EVOLUTION.PROXY.PASSWORD_PLACEHOLDER')
              "
              class="w-full"
            />
          </div>
        </div>

        <NextButton
          :label="$t('INBOX_MGMT.ADD.EVOLUTION.PROXY.UPDATE')"
          :is-loading="isLoading"
          :disabled="!hasValidProxyConfig"
          @click="updateProxySettings"
        />
      </div>
    </SettingsSection>

    <!-- Advanced Settings -->
    <SettingsSection
      :title="$t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.TITLE')"
      :sub-title="$t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.SUBTITLE')"
    >
      <div class="space-y-4">
        <!-- Call Settings -->
        <div class="space-y-3">
          <h4 class="font-medium text-gray-700">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.CALLS.TITLE') }}
          </h4>

          <div class="flex items-center gap-2">
            <input
              id="rejectCall"
              v-model="instanceSettings.rejectCall"
              type="checkbox"
            />
            <label for="rejectCall" class="text-sm">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.CALLS.REJECT') }}
            </label>
          </div>

          <div v-if="instanceSettings.rejectCall">
            <label class="block text-sm font-medium mb-1">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.CALLS.MESSAGE') }}
            </label>
            <input
              v-model="instanceSettings.msgCall"
              type="text"
              :placeholder="
                $t(
                  'INBOX_MGMT.ADD.EVOLUTION.SETTINGS.CALLS.MESSAGE_PLACEHOLDER'
                )
              "
              class="w-full"
            />
          </div>
        </div>

        <!-- Group Settings -->
        <div class="space-y-3">
          <h4 class="font-medium text-gray-700">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.GROUPS.TITLE') }}
          </h4>

          <div class="flex items-center gap-2">
            <input
              id="groupsIgnore"
              v-model="instanceSettings.groupsIgnore"
              type="checkbox"
            />
            <label for="groupsIgnore" class="text-sm">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.GROUPS.IGNORE') }}
            </label>
          </div>
        </div>

        <!-- Status Settings -->
        <div class="space-y-3">
          <h4 class="font-medium text-gray-700">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.STATUS.TITLE') }}
          </h4>

          <div class="flex items-center gap-2">
            <input
              id="alwaysOnline"
              v-model="instanceSettings.alwaysOnline"
              type="checkbox"
            />
            <label for="alwaysOnline" class="text-sm">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.STATUS.ALWAYS_ONLINE') }}
            </label>
          </div>
        </div>

        <!-- Message Settings -->
        <div class="space-y-3">
          <h4 class="font-medium text-gray-700">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.MESSAGES.TITLE') }}
          </h4>

          <div class="flex items-center gap-2">
            <input
              id="readMessages"
              v-model="instanceSettings.readMessages"
              type="checkbox"
            />
            <label for="readMessages" class="text-sm">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.MESSAGES.READ') }}
            </label>
          </div>

          <div class="flex items-center gap-2">
            <input
              id="readStatus"
              v-model="instanceSettings.readStatus"
              type="checkbox"
            />
            <label for="readStatus" class="text-sm">
              {{ $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.MESSAGES.READ_STATUS') }}
            </label>
          </div>

          <div class="flex items-center gap-2">
            <input
              id="syncFullHistory"
              v-model="instanceSettings.syncFullHistory"
              type="checkbox"
            />
            <label for="syncFullHistory" class="text-sm">
              {{
                $t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.MESSAGES.SYNC_HISTORY')
              }}
            </label>
          </div>
        </div>

        <NextButton
          :label="$t('INBOX_MGMT.ADD.EVOLUTION.SETTINGS.UPDATE')"
          :is-loading="isLoading"
          @click="updateInstanceSettings"
        />
      </div>
    </SettingsSection>
  </div>
</template>
