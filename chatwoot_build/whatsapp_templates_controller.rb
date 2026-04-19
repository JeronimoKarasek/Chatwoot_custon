class Api::V1::Accounts::WhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_whatsapp_cloud_channel

  def index
    service = Whatsapp::TemplateManagementService.new(@inbox.channel)
    result = service.list_templates(filter_params)

    if result[:success]
      render json: { data: result[:templates] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def create
    service = Whatsapp::TemplateManagementService.new(@inbox.channel)
    result = service.create_template(template_params)

    if result[:success]
      # Trigger template sync to update the local cache
      Channels::Whatsapp::TemplatesSyncJob.perform_later(channel: @inbox.channel)
      render json: { data: result[:template] }, status: :created
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def update
    service = Whatsapp::TemplateManagementService.new(@inbox.channel)
    result = service.update_template(params[:id], template_params)

    if result[:success]
      Channels::Whatsapp::TemplatesSyncJob.perform_later(channel: @inbox.channel)
      render json: { data: result[:template] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def destroy
    template_name = params[:name] || params[:id]
    return render json: { error: 'Template name is required' }, status: :bad_request if template_name.blank?

    service = Whatsapp::TemplateManagementService.new(@inbox.channel)
    result = service.delete_template(template_name)

    if result[:success]
      Channels::Whatsapp::TemplatesSyncJob.perform_later(channel: @inbox.channel)
      render json: { success: true }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :update?
  end

  def validate_whatsapp_cloud_channel
    return if @inbox.channel_type == 'Channel::Whatsapp' && @inbox.channel&.provider == 'whatsapp_cloud'

    render json: { error: 'This feature is only available for WhatsApp Cloud API inboxes' },
           status: :bad_request
  end

  def filter_params
    params.permit(:name, :limit)
  end

  def template_params
    params.require(:template).permit(
      :name, :language, :category,
      components: [
        :type, :format, :text,
        example: {},
        buttons: [:type, :text, :url, :phone_number, example: []]
      ]
    ).to_h.deep_symbolize_keys
  end
end
