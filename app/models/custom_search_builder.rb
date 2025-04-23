# app/models/custom_search_builder.rb 

class CustomSearchBuilder < Hyrax::CatalogSearchBuilder
    self.default_processor_chain += [:add_custom_filters]
  
    def add_custom_filters(solr_parameters)
      logic = blacklight_params[:search_logic] || []
      fields = blacklight_params[:search_field] || []
      operators = blacklight_params[:search_operator] || []
      queries = blacklight_params[:search_query] || []
  
      combined_query = build_combined_query(logic, fields, operators, queries)
      solr_parameters[:q] = combined_query
    end
  
    private
  
    #--------Advance Search------#
    # Build a combined Solr query based on user inputs
    def build_combined_query(logic, fields, operators, queries)
        query_parts = []
        
        queries.each_with_index do |query, index|
        next if query.blank?
    
        field = fields[index]
        operator = operators[index]
    
        solr_field = map_field_to_solr(field)
        solr_operator = map_operator_to_solr(operator, query)
    
        query_parts << solr_operator % { field: solr_field, query: query }
        end
    
        # Join query parts using the provided logic (AND, OR, NOT)
        combined_query = query_parts.each_with_index.map do |part, i|
        i.zero? ? part : "#{logic[i - 1]} #{part}"
        end.join(' ')
    
        combined_query.presence || '*:*' # If no query, return all results
    end
    
    def map_field_to_solr(field)
        field_mappings = {
        "abstract" => "abstract_tesim",
        "contributor" => "contributor_tesim",
        "copyright_note" => "copyright_note_tesim",
        "creator" => "creator_tesim",
        "doi" => "digital_object_identifier_tesim",
        "keyword" => "keyword_tesim",
        "publisher" => "publisher_tesim",
        "reference_no" => "identifier_tesim",
        "subject" => "subject_tesim",
        "title" => "title_tesim"
        }
        field_mappings[field] || "all_text_timv" # Default to "Any Field"
    end
    
    def map_operator_to_solr(operator, query)
        case operator
        when "contains"
        "%{field}:*%{query}*"
        when "starts_with"
        "%{field}:%{query}*"
        when "equals"
        "%{field}:%{query}"
        else
        "%{field}:*%{query}*" # Default to "contains"
        end
    end
    
    
    #--------Advance Search------#
  end
  