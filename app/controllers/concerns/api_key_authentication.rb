# An API key in X-Api-Key or Authorization: Bearer (ApiKey), allowed the
# scope an endpoint needs. Sets @api_key.
module ApiKeyAuthentication
  extend ActiveSupport::Concern

  private

  def authenticate_api_key!(scope)
    token = request.headers['X-Api-Key'].presence ||
            request.authorization.to_s[/\ABearer (.+)\z/, 1]
    @api_key = ApiKey.authenticate(token)
    if @api_key.nil?
      error = if token.present?
                'Invalid or revoked API key. Contact SigmaTenders if you need a new one.'
              else
                'API key required: send it in the X-Api-Key header. Contact SigmaTenders to request one.'
              end
      return render json: { error: }, status: :unauthorized
    end
    return render json: { error: "This key can't use #{scope}." }, status: :forbidden unless @api_key.allows?(scope)

    @api_key.record_use!
  end
end
