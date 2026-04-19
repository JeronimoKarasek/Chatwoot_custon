# frozen_string_literal: true

# =============================================================================
# FarolChat: Canned Response - Personal (per-agent) + Audio Support
# =============================================================================
#
# Features:
#   1. Each agent can create personal canned responses (visible only to them)
#   2. Canned responses can be audio recordings (stored via ActiveStorage/S3)
#   3. Account-level (shared) canned responses continue to work as before
#
# DB Changes (idempotent):
#   - Add user_id (integer, nullable) to canned_responses
#   - Add response_type (string, default 'text') to canned_responses
#   - Add index on [account_id, user_id]
#
# =============================================================================

Rails.application.config.after_initialize do
  Rails.logger.info 'CannedResponsePersonalAudioPatch: Loading...'

  # ============================================================================
  # 1. Idempotent Migration
  # ============================================================================
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    unless conn.column_exists?(:canned_responses, :user_id)
      conn.add_column :canned_responses, :user_id, :integer, null: true
      Rails.logger.info 'CannedResponsePersonalAudioPatch: Added user_id column'
    end

    unless conn.column_exists?(:canned_responses, :response_type)
      conn.add_column :canned_responses, :response_type, :string, default: 'text', null: false
      Rails.logger.info 'CannedResponsePersonalAudioPatch: Added response_type column'
    end

    unless conn.index_exists?(:canned_responses, [:account_id, :user_id])
      conn.add_index :canned_responses, [:account_id, :user_id], name: 'index_canned_responses_on_account_and_user'
      Rails.logger.info 'CannedResponsePersonalAudioPatch: Added composite index'
    end

    # Add foreign key if not exists
    unless conn.foreign_key_exists?(:canned_responses, :users)
      conn.add_foreign_key :canned_responses, :users, on_delete: :nullify
      Rails.logger.info 'CannedResponsePersonalAudioPatch: Added foreign key to users'
    end
  end

  # Reset column info so ActiveRecord picks up new columns
  CannedResponse.reset_column_information

  # ============================================================================
  # 2. Model Patch
  # ============================================================================
  CannedResponse.class_eval do
    belongs_to :user, optional: true

    has_one_attached :audio

    # Override original uniqueness validation:
    # short_code unique per (account_id, user_id) — allows same shortcode
    # for different users or shared vs personal
    _validators.reject! { |key, _| key == :short_code }
    _validate_callbacks.each do |callback|
      if callback.filter.is_a?(ActiveRecord::Validations::UniquenessValidator) &&
         callback.filter.attributes.include?(:short_code)
        callback.filter.instance_variable_set(:@options,
          callback.filter.options.merge(scope: [:account_id, :user_id]))
      end
    end

    # Validate audio presence for audio type
    validate :audio_required_for_audio_type

    # Scopes
    scope :personal, ->(user) { where(user_id: user.id) }
    scope :shared, -> { where(user_id: nil) }
    scope :available_for, ->(user) { where(user_id: [nil, user.id]) }

    # Content not required for audio type
    _validators[:content]&.reject! { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
    _validate_callbacks.each do |callback|
      next unless callback.filter.is_a?(ActiveModel::Validations::PresenceValidator)
      next unless callback.filter.attributes.include?(:content)

      # Replace with conditional presence
      callback.filter.instance_variable_set(:@options,
        callback.filter.options.merge(if: -> { response_type != 'audio' }))
    end

    def personal?
      user_id.present?
    end

    def audio_type?
      response_type == 'audio'
    end

    def audio_url
      return nil unless audio.attached?

      Rails.application.routes.url_helpers.rails_blob_url(
        audio,
        disposition: 'inline',
        host: ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
      )
    end

    private

    def audio_required_for_audio_type
      return unless audio_type?
      return if audio.attached?
      return if persisted? && !response_type_changed?

      errors.add(:audio, 'is required for audio responses')
    end
  end

  Rails.logger.info 'CannedResponsePersonalAudioPatch: Model patched'

  # ============================================================================
  # 3. Controller Patch
  # ============================================================================
  Api::V1::Accounts::CannedResponsesController.class_eval do
    # Override index to return available_for(current_user)
    def index
      render json: canned_responses_list.map { |cr| serialize_canned_response(cr) }
    end

    def create
      @canned_response = Current.account.canned_responses.new(canned_response_create_params)
      @canned_response.user_id = current_user.id if params[:canned_response][:personal].present? &&
                                                     ActiveModel::Type::Boolean.new.cast(params[:canned_response][:personal])
      @canned_response.save!
      render json: serialize_canned_response(@canned_response)
    end

    def update
      authorize_personal_response!(@canned_response)
      update_params = canned_response_update_params
      @canned_response.update!(update_params)
      render json: serialize_canned_response(@canned_response)
    end

    def destroy
      authorize_personal_response!(@canned_response)
      @canned_response.destroy!
      head :ok
    end

    # GET /api/v1/accounts/:account_id/canned_responses/:id/audio
    def audio
      cr = Current.account.canned_responses.find(params[:id])
      if cr.audio.attached?
        # Stream the audio directly to avoid CORS issues with S3
        send_data cr.audio.download,
                  type: cr.audio.content_type,
                  disposition: 'inline',
                  filename: cr.audio.filename.to_s
      else
        head :not_found
      end
    end

    private

    def fetch_canned_response
      @canned_response = Current.account.canned_responses.find(params[:id])
    end

    def authorize_personal_response!(response)
      return if current_user_is_admin?
      return unless response.personal?
      return if response.user_id == current_user.id

      render json: { error: 'Unauthorized: you can only manage your own personal responses' }, status: :forbidden
    end

    def current_user_is_admin?
      Current.account_user&.administrator? || current_user.type == 'SuperAdmin'
    end

    def canned_response_create_params
      permitted = params.require(:canned_response).permit(:short_code, :content, :response_type, :audio)
      permitted
    end

    def canned_response_update_params
      params.require(:canned_response).permit(:short_code, :content, :response_type, :audio)
    end

    def canned_responses_list
      scope = Current.account.canned_responses.available_for(current_user)
      if params[:search].present?
        scope = scope.where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
                     .order_by_search(params[:search])
      end
      scope.includes(:user, audio_attachment: :blob)
    end

    def serialize_canned_response(cr)
      data = {
        id: cr.id,
        account_id: cr.account_id,
        short_code: cr.short_code,
        content: cr.content,
        response_type: cr.response_type || 'text',
        personal: cr.personal?,
        user_id: cr.user_id,
        created_at: cr.created_at,
        updated_at: cr.updated_at
      }
      if cr.user.present?
        data[:user_name] = cr.user.available_name || cr.user.name
      end
      if cr.audio_type? && cr.audio.attached?
        data[:audio_url] = cr.audio_url
        data[:audio_content_type] = cr.audio.content_type
        data[:audio_filename] = cr.audio.filename.to_s
        data[:audio_byte_size] = cr.audio.byte_size
      end
      data
    end
  end

  Rails.logger.info 'CannedResponsePersonalAudioPatch: Controller patched'

  # ============================================================================
  # 4. Add audio route
  # ============================================================================
  Rails.application.routes.prepend do
    namespace :api, defaults: { format: 'json' } do
      namespace :v1 do
        resources :accounts, only: [], module: :accounts do
          resources :canned_responses, only: [] do
            member do
              get :audio
            end
          end
        end
      end
    end
  end

  Rails.logger.info 'CannedResponsePersonalAudioPatch: Routes patched'
  Rails.logger.info 'CannedResponsePersonalAudioPatch: Fully loaded!'
end
