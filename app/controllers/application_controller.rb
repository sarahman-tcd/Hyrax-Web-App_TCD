class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  skip_after_action :discard_flash_if_xhr
  include Hydra::Controller::ControllerBehavior

  # Adds Hyrax behaviors into the application controller
  include Hyrax::Controller
  include Hyrax::ThemedLayoutController
  with_themed_layout '1_column'

  protect_from_forgery with: :exception

  # -----------------------------------------------------------------------
  # Targeted error handling — prevents stack traces from leaking to users.
  #
  # Strategy:
  #   - Specific rescue_from handlers for known "safe" exception types only.
  #   - CanCan::AccessDenied is NOT overridden here — Hyrax already handles
  #     it with proper login redirects. Overriding it would break auth flow.
  #   - StandardError is NOT caught here — Rails production config already
  #     serves public/500.html for unhandled exceptions when
  #     config.consider_all_requests_local = false (set in production.rb).
  #   - Nginx error_page directives (ops/webapp*.conf) catch proxy-level
  #     errors (e.g., Max-Forwards: 0) before they reach Rails.
  # -----------------------------------------------------------------------
  rescue_from ActionController::RoutingError,  with: :render_404
  rescue_from ActiveRecord::RecordNotFound,    with: :render_404
  rescue_from ActionController::UnknownFormat, with: :render_404

  private

  def render_404(exception = nil)
    if exception
      Rails.logger.info "Rendering 404 for #{exception.class}: #{exception.message}"
    end
    respond_to do |format|
      format.html { render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false }
      format.json { render json: { error: 'Not found' }, status: :not_found }
      format.any  { head :not_found }
    end
  end
end
