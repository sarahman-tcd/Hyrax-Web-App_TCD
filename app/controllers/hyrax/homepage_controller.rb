require 'json'

class Hyrax::HomepageController < ApplicationController
  # Adds Hydra behaviors into the application controller
  include Blacklight::SearchContext
  include Blacklight::SearchHelper
  include Blacklight::AccessControls::Catalog

  # The search builder for finding recent documents
  # Override of Blacklight::RequestBuilders
  def search_builder_class
    Hyrax::HomepageSearchBuilder
  end

  class_attribute :presenter_class
  self.presenter_class = Hyrax::HomepagePresenter
  layout 'homepage'
  helper Hyrax::ContentBlockHelper

  def index
    @presenter = presenter_class.new(current_ability, collections)
    @featured_researcher = ContentBlock.for(:researcher)
    @marketing_text = ContentBlock.for(:marketing)
    @featured_work_list = FeaturedWorkList.new
    @announcement_text = ContentBlock.for(:announcement)
    recent
  end

  private

    # Return 10 collections
    # def collections(rows: 18)
    #   builder = Hyrax::CollectionSearchBuilder.new(self)
    #                                           .rows(rows)
    #   response = repository.search(builder)
    #   response.documents
    # rescue Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest
    #   []
    # end

    def collections(rows: 20)
      builder = Hyrax::CollectionSearchBuilder.new(self)
                                              .rows(rows)
      response = repository.search(builder)
      collection_response=response.documents

      # Read JSON file and parse its content
      file_path = Rails.root.join('public', 'tileOrder.json')
      tile_order_data = JSON.parse(File.read(file_path))

      # Create a hash to store tile order based on collection ID
      tile_order_hash = {}
      tile_order_data.each { |item| tile_order_hash[item['collection_id']] = item['tile_order'].to_i }
    
      # Filter out collections with tile orders outside the range of 1 to 18
      sorted_collection = collection_response.select do |collection|
        collection_id = collection['id']
        tile_order = tile_order_hash[collection_id]
        tile_order.present? && tile_order.to_i != 0 && (1..18).cover?(tile_order.to_i)
      end

      # Sort the filtered collections based on their tile orders
      sorted_collection.sort_by! { |collection| tile_order_hash[collection['id']] }

      # Log collection id and tile order for each sorted collection
      sorted_collection.each do |collection|
        collection_id = collection['id']
        tile_order = tile_order_hash[collection_id]
        Rails.logger.debug "Collection ID: #{collection_id}, Tile Order: #{tile_order}"
      end

      sorted_collection

    rescue Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest
      []
    end

    def recent
      # grab any recent documents
      (_, @recent_documents) = search_results(q: '', sort: sort_field, rows: 10)
    rescue Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest
      @recent_documents = []
    end

    def sort_field
      "#{Solrizer.solr_name('date_uploaded', :stored_sortable, type: :date)} desc"
    end
end