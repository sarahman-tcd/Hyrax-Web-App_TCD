class IIIFParamsConstraint
    def matches?(request)
      uri = URI.parse(request.original_url)
      uri.query.nil? || uri.query.empty?
    end
  end