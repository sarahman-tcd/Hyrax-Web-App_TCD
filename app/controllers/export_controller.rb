class ExportController < ApplicationController
  include Hydra::Controller::ControllerBehavior
  #require 'iso-639'

  def dublinCore

    objectId = params[:id]

    begin
      obj  = ActiveFedora::Base.find(objectId, cast: true)

      builder = obj.to_dublin_core

      respond_to do |format|
       format.html
       format.xml { render xml: builder  }
      end
    rescue => e
      Rails.logger.error "ExportController#dublinCore error (#{e.class}) for objid #{params[:id]}: #{e.message}\n#{e.backtrace&.join("\n")}"
    end

  end
end
