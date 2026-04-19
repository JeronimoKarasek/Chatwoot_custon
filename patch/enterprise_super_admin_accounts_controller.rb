module Enterprise::SuperAdmin::AccountsController
  def create
    # Remove manually_managed_features from params before create to prevent
    # ActiveModel::UnknownAttributeError 
    if params[:account] && params[:account][:manually_managed_features].present?
      service_class = ::Internal::Accounts::InternalAttributesService rescue nil
      if service_class
        # We can't set manually_managed_features before the account exists,
        # so we'll handle it after creation
        @pending_manually_managed_features = params[:account][:manually_managed_features]
      end
      params[:account].delete(:manually_managed_features)
    end

    super
  end

  def update
    # Handle manually managed features from form submission
    if params[:account] && params[:account][:manually_managed_features].present?
      service = ::Internal::Accounts::InternalAttributesService.new(requested_resource)
      service.manually_managed_features = params[:account][:manually_managed_features]

      # Remove the manually_managed_features from params to prevent ActiveModel::UnknownAttributeError
      params[:account].delete(:manually_managed_features)
    end

    super
  end
end
