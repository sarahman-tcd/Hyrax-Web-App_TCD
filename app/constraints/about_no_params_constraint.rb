class AboutNoParamsConstraint
    def matches?(request)
      # Check if the request path matches '/about' exactly
      request.path == '/about'
    end
  end