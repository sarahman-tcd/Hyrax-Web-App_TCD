class AutocompleteController < ApplicationController
  # AJAX endpoint to fetch matching titles for autocomplete
  def titles
    begin
      query = params[:term].to_s.strip  # jQuery UI sends 'term' parameter
      
      # Return empty array if query is too short
      if query.length < 2
        render json: []
        return
      end
      
      # Query Solr for titles matching the search term
      solr = Blacklight.default_index.connection
      
      # Efficient query: only fetch titles that match the user's input
      solr_params = {
        q: "*:* AND -human_readable_type_sim:Collection AND title_tesim:*#{query}*",
        fl: 'title_tesim',
        rows: 15  # Only fetch 15 matching results
      }
      
      Rails.logger.debug "Autocomplete query: #{solr_params[:q]}"
      
      response = solr.get('select', params: solr_params)
      docs = response.dig('response', 'docs') || []
      
      Rails.logger.debug "Found #{docs.size} documents"
      
      # Extract only unique titles (not file names or other fields)
      titles = []
      docs.each do |doc|
        if doc['title_tesim'].is_a?(Array)
          # Only add actual titles, filter out file names
          doc['title_tesim'].each do |title|
            # Skip if it looks like a file name (has extension)
            next if title.match?(/\.(jpg|jpeg|png|gif|pdf|tif|tiff|xml|txt)$/i)
            titles << title if title.is_a?(String)
          end
        elsif doc['title_tesim'].is_a?(String)
          title = doc['title_tesim']
          # Skip if it looks like a file name
          next if title.match?(/\.(jpg|jpeg|png|gif|pdf|tif|tiff|xml|txt)$/i)
          titles << title
        end
      end
      
      # Remove duplicates, sort, and limit to 10
      titles = titles.compact.uniq.sort.first(10)
      
      Rails.logger.debug "Returning #{titles.size} unique titles"
      Rails.logger.debug "Titles: #{titles.inspect}"
      
      render json: titles
    rescue => e
      Rails.logger.error "Autocomplete error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: [], status: :ok
    end
  end
end
