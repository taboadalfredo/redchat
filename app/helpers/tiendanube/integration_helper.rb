module Tiendanube::IntegrationHelper
  REQUIRED_SCOPES = %w[read_customers read_orders read_fulfillments].freeze

  private

  def client_id
    @client_id ||= GlobalConfigService.load('TIENDANUBE_CLIENT_ID', nil)
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('TIENDANUBE_CLIENT_SECRET', nil)
  end
end
