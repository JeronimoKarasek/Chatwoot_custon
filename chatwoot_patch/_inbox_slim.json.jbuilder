json.id resource.id
json.avatar_url resource.try(:avatar_url)
json.channel_id resource.channel_id
json.name resource.name
json.channel_type resource.channel_type
json.provider resource.channel.try(:provider)
json.phone_number resource.channel.try(:phone_number)

# Expose provider_type for Evolution Channel::Api inboxes
if resource.api? && resource.channel.try(:additional_attributes).present?
  attrs = resource.channel.additional_attributes
  if attrs['provider_type'] == 'evolution'
    json.provider_config do
      json.provider_type 'evolution'
      json.phone_number attrs['phone_number']
    end
  end
end

# Fallback: legacy WhatsApp Evolution inboxes
if resource.whatsapp? && resource.channel.try(:provider_config).present?
  json.provider_config do
    json.provider_type resource.channel.provider_config['provider_type']
  end
end
