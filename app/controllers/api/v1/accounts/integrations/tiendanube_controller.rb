class Api::V1::Accounts::Integrations::TiendanubeController < Api::V1::Accounts::BaseController
  include Tiendanube::IntegrationHelper

  TIENDANUBE_API_BASE = 'https://api.tiendanube.com/v1'.freeze
  TIENDANUBE_TOKEN_URL = 'https://www.tiendanube.com/apps/authorize/token'.freeze

  before_action :fetch_hook, only: [:orders, :destroy]
  before_action :validate_contact, only: [:orders]

  def auth
    code = params[:code]
    return render json: { error: 'Code is required' }, status: :unprocessable_entity if code.blank?
    return render json: { error: 'TiendaNube integration not configured' }, status: :unprocessable_entity if client_id.blank? || client_secret.blank?

    token_response = exchange_code_for_token(code)

    create_integration_hook(token_response)

    render json: { success: true }
  rescue StandardError => e
    Rails.logger.error("TiendaNube auth error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def orders
    customers = fetch_customers
    return render json: { orders: [] } if customers.empty?

    orders = fetch_orders_for_customer(customers.first['id'])
    render json: { orders: orders }
  rescue StandardError => e
    Rails.logger.error("TiendaNube API error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def exchange_code_for_token(code)
    request_body = {
      client_id: client_id,
      client_secret: client_secret,
      grant_type: 'authorization_code',
      code: code
    }

    Rails.logger.info("TiendaNube Auth Request - URL: #{TIENDANUBE_TOKEN_URL}")
    Rails.logger.info("TiendaNube Auth Request - Body: #{request_body.merge(client_secret: '[REDACTED]').to_json}")

    response = HTTParty.post(
      TIENDANUBE_TOKEN_URL,
      headers: { 'Content-Type' => 'application/json' },
      body: request_body.to_json
    )

    Rails.logger.info("TiendaNube Auth Response - Status: #{response.code}")
    Rails.logger.info("TiendaNube Auth Response - Body: #{response.body}")

    raise StandardError, "Token exchange failed: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  def create_integration_hook(token_response)
    Current.account.hooks.create!(
      app_id: 'tiendanube',
      access_token: token_response['access_token'],
      status: 'enabled',
      reference_id: token_response['user_id'].to_s,
      settings: {
        store_id: token_response['user_id'].to_s,
        scope: token_response['scope'],
        token_type: token_response['token_type']
      }
    )
  end

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'tiendanube')
  end

  def store_id
    @hook.settings['store_id']
  end

  def api_headers
    {
      'Authentication' => "bearer #{@hook.access_token}",
      'User-Agent' => 'Chatwoot (support@chatwoot.com)',
      'Content-Type' => 'application/json'
    }
  end

  def fetch_customers
    return [] if contact.email.blank? && contact.phone_number.blank?

    query_params = {}
    query_params[:email] = contact.email if contact.email.present?
    query_params[:phone] = contact.phone_number if contact.phone_number.present? && query_params.empty?

    response = HTTParty.get(
      "#{TIENDANUBE_API_BASE}/#{store_id}/customers",
      headers: api_headers,
      query: query_params
    )

    return [] unless response.success?

    response.parsed_response || []
  end

  def fetch_orders_for_customer(customer_id)
    response = HTTParty.get(
      "#{TIENDANUBE_API_BASE}/#{store_id}/orders",
      headers: api_headers,
      query: { customer_id: customer_id }
    )

    return [] unless response.success?

    orders = response.parsed_response || []
    orders.map do |order|
      order.merge(
        'admin_url' => "https://#{store_id}.mitiendanube.com/admin/orders/#{order['id']}"
      )
    end
  end

  def validate_contact
    return unless contact.blank? || (contact.email.blank? && contact.phone_number.blank?)

    render json: { error: 'Contact information missing' },
           status: :unprocessable_entity
  end
end
