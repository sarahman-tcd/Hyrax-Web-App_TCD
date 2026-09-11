class DoiController < ApplicationController

  before_action :authenticate_user!
  before_action :ensure_admin!

  def ensure_admin!
      authorize! :read, :admin_dashboard
  end

  def createDoi
    objectId = params[:id]

    begin
      obj  = ActiveFedora::Base.find(objectId, cast: true)

      # check if public, that DOI doesn't already exist, and objectId is not on the DOI Blocker List
      if (obj.visibility != 'open') || (!obj.doi.nil?) || DoiBlockerLists.exists?(object_id: objectId)
        flash[:error] = "DOI requests can only be requested if object is public, does not already have a DOI, and is not on the DOI blocker list"
        redirect_back(fallback_location: root_path)
      else
        GenerateDoiJob.perform_later(objectId)
        flash[:notice] = "DOI request has been submitted. Check jobs in sidekiq, then refresh your Work/Folio/Subseries to see the new DOI"
        redirect_back(fallback_location: root_path)
      end
    rescue StandardError => e
      Rails.logger.error "DoiController#createDoi error (#{e.class}) for objid #{params[:id]}: #{e.message}\n#{e.backtrace&.join("\n")}"
      flash[:error] = "An unexpected error occurred while attempting to create the DOI."
      redirect_back(fallback_location: root_path)
    end


  end

end
