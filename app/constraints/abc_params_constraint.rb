class AbcParamsConstraint
  ALLOWED_PARAMS = ['locale'].freeze
  ALLOWED_LOCALES = ['en', 'pt-BR', 'de', 'es', 'fr', 'ga', 'it', 'zh'].freeze

  def matches?(request)
    query_params = request.query_parameters
    # Check if all parameters are allowed
    unless query_params.keys.all? { |key| ALLOWED_PARAMS.include?(key) || key.blank? }
      raise ActionController::BadRequest.new('Bad Request')
    end

    # If locale is present, check if its value is allowed
    if query_params.key?('locale') && !query_params['locale'].blank?
      locale = query_params['locale']
      unless ALLOWED_LOCALES.include?(locale)
        raise ActionController::BadRequest.new('Bad Request')
      end
    end

    true # Allow the request to proceed
  end
end