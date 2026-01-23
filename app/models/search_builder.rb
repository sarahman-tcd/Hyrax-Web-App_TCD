# frozen_string_literal: true
class SearchBuilder < Hyrax::CatalogSearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  # Add a filter query to restrict the search to documents the current user has access to
  include Hydra::AccessControlsEnforcement
  include Hyrax::SearchFilters

  self.default_processor_chain += [:force_lucene_parser]

  def force_lucene_parser(solr_parameters)
    if blacklight_params[:advanced_search] == 'true'
      solr_parameters[:defType] = 'lucene'
    end
  end
end
