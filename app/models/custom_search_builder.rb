# app/models/custom_search_builder.rb
require_dependency 'solr_sanitizer'

class CustomSearchBuilder < Hyrax::CatalogSearchBuilder
    self.default_processor_chain += [:add_custom_filters]

    # Whitelist constants – prevent unknown field/operator values reaching Solr
    ALLOWED_FIELDS = %w[
      any title creator contributor abstract keyword
      publisher subject identifier date_created
      copyright_note doi reference_no
    ].freeze

    ALLOWED_OPERATORS = %w[contains starts_with equals exact].freeze

    ALLOWED_LOGIC = %w[AND OR NOT].freeze

    def add_custom_filters(solr_parameters)
      logic     = blacklight_params[:search_logic]    || []
      fields    = blacklight_params[:search_field]    || []
      operators = blacklight_params[:search_operator] || []
      queries   = blacklight_params[:search_query]    || []

      # Sanitize every user-supplied query value before building the Solr query
      safe_queries = queries.map { |q| SolrSanitizer.escape(q.to_s) }

      combined_query = build_combined_query(logic, fields, operators, safe_queries)
      solr_parameters[:q] = combined_query
    end

    private

    #--------Advance Search------#
    # Build a combined Solr query based on user inputs
    def build_combined_query(logic, fields, operators, queries)
        query_parts = []

        queries.each_with_index do |query, index|
        next if query.blank?

        # Security: Validate query length (prevent DoS)
        next if query.length > 1000

        field    = fields[index].to_s.downcase
        operator = operators[index].to_s.downcase

        # Security: validate field and operator against whitelists
        next unless ALLOWED_FIELDS.include?(field)
        next unless ALLOWED_OPERATORS.include?(operator)

        # Security: validate logic operator if present
        if index > 0 && logic[index - 1]
          next unless ALLOWED_LOGIC.include?(logic[index - 1].to_s.upcase)
        end

        solr_field   = map_field_to_solr(field)
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
          "any"            => "all_text_timv",
          "abstract"       => "abstract_tesim",
          "contributor"    => "contributor_tesim",
          "copyright_note" => "copyright_note_tesim",
          "creator"        => "creator_tesim",
          "doi"            => "doi_tesim",
          "keyword"        => "keyword_tesim",
          "publisher"      => "publisher_tesim",
          "reference_no"   => "identifier_tesim",
          "subject"        => "subject_tesim",
          "title"          => "title_tesim"
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