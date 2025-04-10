require 'rest-client'
require 'net/http'
 require 'json'
 require 'uri'


class CatalogController < ApplicationController
 include Hydra::Catalog
 include Hydra::Controller::ControllerBehavior  
 include Blacklight::Catalog
 include Blacklight::SearchHelper
 protect_from_forgery with: :null_session
 # This filter applies the hydra access controls
 before_action :enforce_show_permissions, only: :show

 def self.uploaded_field
   solr_name('system_create', :stored_sortable, type: :date)
 end

 def self.modified_field
   solr_name('system_modified', :stored_sortable, type: :date)
 end

 def self.identifier_first_field
   solr_name('identifier_tesim', :stored_sortable, type: :string) # This assumes Solr can sort on the first value
 end

 #--------Tile Order------#
 def get_title_orders
   @data = read_existing_data
   respond_to do |format|
     format.json { render json: @data }
   end
 end

 def save_tile_order
   collection_id = params[:addTextId]
   tile_order = params[:textboxValue]
  
   if tile_order.blank? || tile_order.to_s.strip == ''
     tile_order = '00'
   elsif !valid_value?(tile_order)
     message = 'the tile order should be between 01 and 18 and numeric'
     render json: { error: message }, status: :unprocessable_entity
     return
   elsif tile_order != '00' && tile_order.to_i < 1 || tile_order.to_i > 18
     message = 'the tile order should be between 01 and 18'
     render json: { error: message }, status: :unprocessable_entity
     return
   end

   # Read existing collection_id from the file
   existing_data = read_existing_data

   if existing_data.any? { |data| data['collection_id'] == collection_id }
     # Check if tile order already exists for another collection
     if existing_data.any? { |data| data['tile_order'] == tile_order && data['collection_id'] != collection_id&& tile_order != '00' }
       message = 'the tile order already exists for another collection'
       render json: { error: message }, status: :unprocessable_entity
       return
     end
     # Update the tile_order if the collection_id already exists
     existing_data.each do |data|
       if data['collection_id'] == collection_id
         data['tile_order'] = tile_order
         break
       end
     end
   else
     # Add new data if the collection_id does not exist
     existing_data << { 'collection_id' => collection_id, 'tile_order' => tile_order }
   end

   write_data(existing_data)
   
   render json: { message: 'Saved successfully' }
 rescue => e
   # If any error occurs during the process, respond with an error message
   Rails.logger.error "Error: #{e.message}, Raised at: #{backtrace}"
   render json: { error: e.message }, status: :unprocessable_entity
 end
 #--------Tile Order------#

 #--------Browse Publisher Location Using Map------#
def browse_location_old
  begin
    # Try to get search results from request body
    all_docs = Rails.cache.read("all_search_results") || [] #params[:documents] || []

    if all_docs.empty?
      Rails.logger.warn "No stored search results found in session"
      render json: { locations: {}, unidentified: {} } and return
    end
    # if all_docs.empty?
    #   Rails.logger.error "No documents received, fallback to fresh Solr query"
    #   search_builder.append(:add_publisher_location_filter)
    #   all_docs = fetch_all_publisher_locations(search_builder)
    # end

    Rails.logger.debug "Total Documents Received: #{all_docs.size}"
    Rails.logger.debug "First Document: #{all_docs.first.inspect}" if all_docs.any?

    # Process the documents as before
    @location_counts = all_docs.group_by { |doc| doc['publisher_location_tesim'].presence }.transform_values(&:count)

    total_count = @location_counts.values.sum
    Rails.logger.debug "Total count: #{total_count}"

    normalized_location_counts = @location_counts.each_with_object({}) do |(location, count), result|
      normalized_location = location.is_a?(Array) ? location.join(', ').strip : location.to_s.strip
      result[normalized_location] ||= 0
      result[normalized_location] += count
    end

    unidentified_count = @location_counts.delete(nil) || 0
    @location_latlong = get_latlong_for_locations(normalized_location_counts)

    Rails.logger.debug "Sending JSON Response: #{@location_latlong.to_json}"

    @unidentified = { "Unidentified" => { count: unidentified_count } }

    render json: { locations: @location_latlong, unidentified: @unidentified }
  rescue => e
    Rails.logger.error "Error: #{e.message}, Raised at: #{e.backtrace.first}"
    render json: { error: e.message }, status: :internal_server_error
  end
end

def browse_location
  begin
    search_params = params.to_unsafe_h.deep_symbolize_keys
    search_params[:q] = params[:q].present? ? params[:q] : '*:*'
    search_params[:page] = 1
    search_params[:rows] = 100  # Default per page; will loop to get all
    Rails.logger.debug "this: BL search param with date: #{search_params}"
    # Optional: extract date range and clean it from query
    user_input = nil
    date_range_match = search_params[:q].match(/date_created_tesim:\[(-?\d{1,4})TO(-?\d{1,4})\]/)
    if date_range_match
      start_year, end_year = date_range_match.captures.map(&:to_i)
      user_input = "#{start_year},#{end_year}"
      search_params[:q].sub!(/AND?\s*\(?date_created_tesim:\[.*?\]\)?/, '')
    end

        Rails.logger.debug "this: BL search param without date: #{search_params}"

    all_results = []
    current_page = 1

    loop do
      search_params[:page] = current_page
      response, docs = search_results(search_params)
      all_results.concat(docs)

      break if docs.size < search_params[:rows].to_i
      current_page += 1
    end

    if start_year && end_year && date_range_match
      all_results = filter_documents_by_date_range(all_results, user_input)
    end

    # Then continue your logic with `all_results`
    normalized_location_counts = Hash.new { |hash, key| hash[key] = { count: 0, ids: [] } }

    all_results.each do |doc|
      raw_location = doc['publisher_location_tesim']&.first || "Unidentified"
      normalized_location = raw_location.is_a?(Array) ? raw_location.join(', ').strip : raw_location.to_s.strip

      normalized_location_counts[normalized_location][:count] += 1
      normalized_location_counts[normalized_location][:ids] << doc['id']
    end

    location_counts = normalized_location_counts.transform_values { |v| v[:count] }
    @location_latlong = get_latlong_for_locations(location_counts)
    unidentified_count = normalized_location_counts.delete("Unidentified")&.dig(:count) || 0
    @unidentified = { "Unidentified" => { count: unidentified_count } }

    render json: {
      locations: @location_latlong,
      unidentified: @unidentified,
      location_ids: normalized_location_counts
    }
  rescue => e
    Rails.logger.error "Error: #{e.message}, Raised at: #{e.backtrace.first}"
    render json: { error: e.message }, status: :internal_server_error
  end
end

 #--------Browse Publisher Location Using Map------#

 #--------Advance Search------#

def index
  super  # Ensure Blacklight handles default behavior
  begin   
    search_params = params.to_unsafe_h.deep_symbolize_keys 
    search_params[:q] = params[:q].present? ? params[:q] : '*:*'
    search_params[:page] = params[:page] || 1  
    search_params[:page] = 1 if params[:location_filter].present? && params[:page].blank?
    search_params[:sort] = params[:sort] || blacklight_config.sort_fields.keys.first
    search_params[:per_page] = params[:per_page] || 10

    date_range_match = search_params[:q].match(/date_created_tesim:\[(-?\d{1,4})TO(-?\d{1,4})\]/)    
    if date_range_match
      start_year, end_year = date_range_match.captures.map(&:to_i)
      search_params[:q].sub!(/AND?\s*\(?date_created_tesim:\[.*?\]\)?/, '') 
    end   
    Rails.logger.debug "this: search param without date: #{search_params}"

    if params[:location_filter].present?
      location_ids = params[:location_filter].split(',')
      location_filter_query = "id:(" + location_ids.map { |id| "\"#{id.strip}\"" }.join(" OR ") + ")"
      
      # Combine this into the existing query
      search_params[:q] = "#{search_params[:q]} AND #{location_filter_query}"
      Rails.logger.debug "this: Final Search Params Sent to SearchBuilder: #{search_params.inspect}"
      @response, @documents = search_results(search_params)
      Rails.logger.debug "this: SOLR returned: #{@response.total} total hits, #{@documents.count} on this page"

      respond_to do |format|
        format.html { render :index }  # Normal page load
        format.json { render json: { response: @response, documents: @documents } }  # API JSON response
        format.js { render partial: 'catalog/search_results', formats: [:js] }  # Ensure JavaScript format is handled
      end
      return
    end

    search_params[:rows] = params[:rows] || 10 

    Rails.logger.debug "this: Final Search Params Sent to SearchBuilder: #{search_params.inspect}"

    all_results = []
    current_page = 1
    loop do
      search_params[:page] = current_page
      response, docs = search_results(search_params)  # Get next batch of documents
      all_results.concat(docs)  # Collect all results
      break if docs.size < search_params[:rows].to_i  # Stop if last page is reached
      current_page += 1
    end

    # Apply date range filter
    if start_year && end_year && date_range_match
      filtered_ids = filter_documents_by_date_range(all_results, "#{start_year},#{end_year}")
       Rails.logger.debug "this: filtered_ids: #{filtered_ids}"
      # Add the filtered IDs into the query string to limit results
      location_filter_query = "id:(" + filtered_ids.map { |id| "\"#{id}\"" }.join(" OR ") + ")"
      search_params[:q] = "#{search_params[:q]} AND #{location_filter_query}"

      Rails.logger.debug "this: Final Search Params with Filtered IDs: #{search_params.inspect}"
    end

    # Perform the search again with the updated parameters (filtered by ID)
    @response, @documents = search_results(search_params)
    Rails.logger.debug "this: Filtered documents count (after applying date filter): #{@documents.count}"

    
  # #==========================================JUST2CACHEaLL4LOCATIONmAP=============================
  #   all_results = []
  #   current_page = 1
    
  #   # Fetch all pages first (without filtering inside the loop)
  #   loop do
  #     search_params[:page] = current_page      
  #     response, docs = search_results(search_params)  # Get next batch of documents
      
  #     all_results.concat(docs)  # Collect all results
    
  #     break if docs.size < search_params[:rows]  # Stop if last page is reached
  #     current_page += 1
  #   end
    
  #   Rails.logger.debug "this: all_results: #{all_results.count}"
  #   # Apply filtering once on the final collected dataset
  #   Rails.logger.debug "all_results: #{user_input}"
  #   # This startYear endYear validation is to check if the date_created_tesim has not been sent.
  #   if start_year && end_year && date_range_match
  #     filtered_results = filter_documents_by_date_range(all_results, user_input)
  #     Rails.logger.debug "this: filtered_results: #{filtered_results.count}"    
  #     # Cache only the final filtered data
  #     Rails.cache.write("all_search_results", filtered_results.map(&:to_h), expires_in: 1.hour)
  #   end 

  # #==================================================================================================================

      Rails.logger.debug "this: the updated returned: #{@response.total} total hits, #{@documents.count} on this page"

    respond_to do |format|
      format.html { render :index }  # Normal page loadSouvenir
      format.json { render json: { response: @response, documents: @documents } }  # API JSON response
      format.js { render partial: 'catalog/search_results', formats: [:js] }  # Ensure JavaScript format is handled
    end
  rescue => e
    Rails.logger.error "Error: #{e.message}, Raised at: #{e.backtrace.first}"
    render json: { error: 'An error occurred during the search.', details: e.message }, status: :internal_server_error
  end
end




 
   
 #--------Advance Search------#
 
 private

 #--------Tile Order------#
 def read_existing_data
   file_path = Rails.root.join('public', 'tileOrder.json')
   File.exist?(file_path) ? JSON.parse(File.read(file_path)) : []
 end

 def write_data(data)
   file_path = Rails.root.join('public', 'tileOrder.json')
   File.open(file_path, 'w') { |file| file.write(JSON.generate(data)) }
 end

 def valid_value?(value)
   value.match?(/\A\d{2}\z/) && value.to_i.between?(1, 18)
 end
 #--------Tile Order------#

 #--------Browse Publisher Location Using Map------#
 def fetch_all_publisher_locations(search_builder)
  start = 0
  batch_size = 100 # Fetch 100 at a time, adjust as needed
  all_docs = []
  loop do
    # Clone search_builder and set start/rows explicitly
    batch_search_builder = search_builder.merge(rows: batch_size, start: start)
    response = repository.search(batch_search_builder)
    docs = response.documents

    Rails.logger.debug "Batch Start: #{start}, Documents Retrieved: #{docs.size}"

    break if docs.size == 0 # Stop if no more results

    all_docs.concat(docs)
    start += batch_size # Move to the next batch

    # Failsafe: Stop if we exceed a reasonable number of documents
    # break if start > 20000 # Adjust this based on your data size
  end
  Rails.logger.debug "Solr Response Size2: #{all_docs.size}"
  all_docs
end

def unique_date_created_values
  solr = Blacklight.default_index.connection
  
  # First, get the total number of records
  total_records = solr.get('select', params: { q: '*:*', rows: 0 }).dig('response', 'numFound')

  params = {
    q: '*:*',
    rows: total_records, # Fetch exactly as many rows as exist
    fl: 'date_created_tesim'
  }

  Rails.logger.debug "Solr Query Params: #{params.inspect}"

  begin
    response = solr.get 'select', params: params
    Rails.logger.debug "Solr Response: #{response.inspect}"

    dates = response.dig('response', 'docs').flat_map { |doc| doc['date_created_tesim'] || [] }

    unique_dates = dates.uniq
    Rails.logger.debug "Extracted Dates: #{dates.inspect}"
    Rails.logger.debug "Unique Dates: #{unique_dates.inspect}"

    unique_dates
  rescue => e
    Rails.logger.error "Error fetching unique dates from Solr: #{e.message}"
    []
  end
end

def filter_documents_by_date_range(documents, user_range)
  start_year, end_year = user_range.split(",").map(&:to_i)
Rails.logger.debug "this: docu count in filter method: #{documents.count} on this page"
  filtered_ids = []  # Initialize an empty array to collect IDs

  documents.each do |doc|
    next unless doc['date_created_tesim'].is_a?(Array) # Ensure it's an array

    # Extract years from all date strings
    extracted_years = doc['date_created_tesim'].flat_map { |date_str| extract_years(date_str) }

    # Handle cases where "start" and "end" are in separate elements
    start_years = doc['date_created_tesim'].grep(/start/i).flat_map { |date_str| extract_years(date_str) }
    end_years = doc['date_created_tesim'].grep(/end/i).flat_map { |date_str| extract_years(date_str) }

    if start_years.any? && end_years.any?
      sorted_years = [start_years.min, end_years.max].sort # Ensure proper order
      combined_range = (sorted_years.first..sorted_years.last).to_a

      # Instead of returning `true`, return `doc` if it's in range
      if combined_range.any? { |year| year.between?(start_year, end_year) }
        filtered_ids << doc['id']  # Collect the document ID if it matches the range
      end
    end

    # Check if any extracted year falls within the user-specified range
    if extracted_years.any? { |year| year.between?(start_year, end_year) }
      filtered_ids << doc['id']  # Collect the document ID if it matches the range
    end
  end
  filtered_ids  # Return the array of filtered IDs
end







def extract_years(date_string)
  years = []

  # Handle explicit 3-4 digit years
  date_string.scan(/\b\d{3,4}\b/) do |year|
    years << year.to_i
  end

  # Convert "B.C." years to negative values
  date_string.scan(/(\d{1,4})\s*B\.C\./i) do |match|
    years << -match.first.to_i
  end

  # Handle ranges like "1860-1879", "1880/1900"
  date_string.scan(/(\d{3,4})[-\/](\d{3,4})/) do |start_year, end_year|
    years.concat((start_year.to_i..end_year.to_i).to_a)
  end

  # Handle centuries like "15th century", "11th Century to 12th Century"
  date_string.scan(/(\d{1,2})\s*(?:th|st|nd|rd)\s*century(?:\s*to\s*(\d{1,2})\s*(?:th|st|nd|rd)\s*century)?/i) do |start_century, end_century|
    start_year = (start_century.to_i - 1) * 100
    end_year = end_century ? (end_century.to_i * 100 - 1) : (start_year + 99)
    years.concat((start_year..end_year).to_a)
  end

  # Handle uncertain years like "[1889?]" or "[190?]"
  date_string.scan(/\[(\d{3})\?\]/) do |match|
    years.concat((match.first.to_i * 10..match.first.to_i * 10 + 9).to_a)
  end

  # Handle "pre-XXXX" (take the year as an endpoint)
  date_string.scan(/pre-(\d{3,4})/) do |match|
    years << match.first.to_i
  end

  # Handle "between XXXX-YYYY" cases
  date_string.scan(/between\s*(\d{3,4})\s*[-\/]\s*(\d{3,4})/i) do |start_year, end_year|
    years.concat((start_year.to_i..end_year.to_i).to_a)
  end

  # Handle "approximately XXXX"
  date_string.scan(/approximately\s*(\d{3,4})/i) do |match|
    years << match.first.to_i
  end

  # Handle "start XXXX" and "end XXXX" as a range
  if date_string.match?(/start/i) && date_string.match?(/end/i)
    start_year = date_string[/start\s*[-\s]*(\d{3,4})/, 1]
    end_year = date_string[/end\s*[-\s]*(\d{3,4})/, 1]
    if start_year && end_year
      years.concat((start_year.to_i..end_year.to_i).to_a)
    end
  end

  # Ensure unique, sorted years
  years.uniq.sort
end

# def add_publisher_location_filter(solr_parameters)
#   solr_parameters[:fq] ||= []
#   solr_parameters[:fq] << 'publisher_location_tesim:[* TO *]'#THIS- why TO and space before and after TO # Filter for docs with this field
#   solr_parameters[:fl] ||= 'id, publisher_location_tesim'     # Return only these fields
# end
 
def get_latlong_for_locations_old(locations_with_count)
  api_key = 'AIzaSyB7n9JSvr5tZX8lZMzTDMNWk9e11MgLYek'
  location_latlong = {}

  locations_with_count.each do |location, count|
    next if location.nil? || location.empty? # Skip invalid locations

    begin
      # Construct the Google Maps Geocoding API URL
      url = URI.parse("https://maps.googleapis.com/maps/api/geocode/json?address=#{URI.encode(location)}&key=#{api_key}")
      Rails.logger.debug "URL: #{url}"

      # Make the HTTP GET request
      response = Net::HTTP.get_response(url)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)

        # Extract the latitude and longitude
        if data['status'] == 'OK' && data['results'].any?
          lat = data['results'][0]['geometry']['location']['lat']
          lng = data['results'][0]['geometry']['location']['lng']

          # Store lat, lng, and count in the hash
          location_latlong[location] = { lat: lat, lng: lng, count: count }
        else
          Rails.logger.error "Failed to geocode location: #{location}. Status: #{data['status']}"
        end
      else
        Rails.logger.error "HTTP request failed for location: #{location}. Status: #{response.code} - #{response.message}"
      end
    rescue StandardError => e
      Rails.logger.error "Error occurred while fetching data for location: #{location}. Error: #{e.message}"
    end
  end

  location_latlong
end  

def get_latlong_for_locations(locations_with_count)
api_key = 'AIzaSyB7n9JSvr5tZX8lZMzTDMNWk9e11MgLYek'
cache_file = Rails.root.join('public', 'cached_locations.json')

# Ensure the cache file exists
unless File.exist?(cache_file)
  File.write(cache_file, '{}')
end

# Load cached data
cached_locations = JSON.parse(File.read(cache_file))

location_latlong = {}

locations_with_count.each do |location, count|
  next if location.nil? || location.empty? # Skip invalid locations
  
  if cached_locations.key?(location)
    # Use cached data
    lat, lng = cached_locations[location]['lat'], cached_locations[location]['lng']
    Rails.logger.debug "Cache hit for #{location}: #{lat}, #{lng}"
  else
    # Call API
    begin
      url = URI.parse("https://maps.googleapis.com/maps/api/geocode/json?address=#{URI.encode(location)}&key=#{api_key}")
      response = Net::HTTP.get_response(url)
      
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        if data['status'] == 'OK' && data['results'].any?
          lat = data['results'][0]['geometry']['location']['lat']
          lng = data['results'][0]['geometry']['location']['lng']
          
          # Store in cache
          cached_locations[location] = { 'lat' => lat, 'lng' => lng }
          File.write(cache_file, JSON.pretty_generate(cached_locations))
        else
          Rails.logger.error "Failed to geocode: #{location}. Status: #{data['status']}"
          next
        end
      else
        Rails.logger.error "HTTP request failed for #{location}: #{response.code} - #{response.message}"
        next
      end
    rescue StandardError => e
      Rails.logger.error "Error fetching data for #{location}: #{e.message}"
      next
    end
  end
  
  location_latlong[location] = { lat: lat, lng: lng, count: count }
end

location_latlong
end
 #--------Browse Publisher Location Using Map------#
 
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
   "any"=> "all_text_timv",
   "abstract_tesim" => "abstract_tesim",
   "contributor_tesim" => "contributor_tesim",
   "copyright_note_tesim" => "copyright_note_tesim",
   "creator_tesim" => "creator_tesim",
   "digital_object_identifier_tesim" => "digital_object_identifier_tesim",
   "keyword_tesim" => "keyword_tesim",
   "publisher_tesim" => "publisher_tesim",
   "identifier_tesim" => "identifier_tesim",
   "subject_tesim" => "subject_tesim",
   "title_tesim" => "title_tesim",
   "date_created_tesim" => "date_created_tesim"
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
 

 configure_blacklight do |config|
   #config.view.gallery.partials = [:index_header, :index]
   config.view.masonry.partials = [:index]
   config.view.slideshow.partials = [:index]


   config.show.tile_source_field = :content_metadata_image_iiif_info_ssm
   config.show.partials.insert(1, :openseadragon)
   config.search_builder_class = Hyrax::CatalogSearchBuilder

   # Show gallery view
   #config.view.gallery.partials = [:index_header, :index]
   #config.view.slideshow.partials = [:index]

   ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
   config.default_solr_params = {
     qt: "search",
     rows: 10,
     qf: "title_tesim description_tesim creator_tesim keyword_tesim culture_tesim abstract_tesim"
   }



   # solr field configuration for document/show views
   config.index.title_field = solr_name("title", :stored_searchable)
   config.index.display_type_field = solr_name("has_model", :symbol)
   config.index.thumbnail_field = 'thumbnail_path_ss'

   # solr fields that will be treated as facets by the blacklight application
   #   The ordering of the field names is the order of the display
   config.add_facet_field solr_name("title", :facetable), label: "Title", limit: 5
   
   config.add_facet_field solr_name("creator", :facetable), limit: 5
   config.add_facet_field solr_name("contributor", :facetable), label: "Contributor", limit: 5
   config.add_facet_field solr_name("keyword", :facetable), limit: 5
   config.add_facet_field solr_name("subject", :facetable), limit: 5
   config.add_facet_field solr_name("language", :facetable), limit: 5
   config.add_facet_field solr_name("based_near_label", :facetable), limit: 5
   config.add_facet_field solr_name("publisher", :facetable), limit: 5
   config.add_facet_field solr_name("genre", :facetable), limit: 5
   config.add_facet_field solr_name("location", :facetable), limit: 2
   config.add_facet_field solr_name("file_format", :facetable), limit: 5
   config.add_facet_field solr_name('member_of_collection_ids', :symbol), limit: 5, label: 'Collections', helper_method: :collection_title_by_id
   config.add_facet_field solr_name("human_readable_type", :facetable), label: "Type", limit: 5
   config.add_facet_field solr_name("resource_type", :facetable), label: "Resource Type", limit: 5


   # The generic_type isn't displayed on the facet list
   # It's used to give a label to the filter that comes from the user profile
   config.add_facet_field solr_name("generic_type", :facetable), if: false

   # Have BL send all facet field names to Solr, which has been the default
   # previously. Simply remove these lines if you'd rather use Solr request
   # handler defaults, or have no facets.
   config.add_facet_fields_to_solr_request!

   # solr fields to be displayed in the index (search results) view
   #   The ordering of the field names is the order of the display
 #JL  config.add_index_field solr_name("title", :stored_searchable), label: "Title", itemprop: 'name', if: false
#JL    config.add_index_field solr_name("description", :stored_searchable), itemprop: 'description', helper_method: :iconify_auto_link
   #config.add_index_field solr_name("abstract", :stored_searchable), itemprop: 'abstract', helper_method: :iconify_auto_link
#JL    config.add_index_field solr_name("alternative_title", :stored_searchable), itemprop: 'alternative_title'
   config.add_index_field solr_name("creator", :stored_searchable), itemprop: 'creator', link_to_search: solr_name("creator", :facetable)
#JL    config.add_index_field solr_name("publisher_location", :stored_searchable), itemprop: 'publisher_location'
#JL    config.add_index_field solr_name("publisher", :stored_searchable), itemprop: 'publisher', link_to_search: solr_name("publisher", :facetable)
#JL    config.add_index_field solr_name("date_created", :stored_searchable), itemprop: 'dateCreated'
#JL    config.add_index_field solr_name("series_title", :stored_searchable), itemprop: 'series_title'
#JL    config.add_index_field solr_name("collection_title", :stored_searchable), itemprop: 'collection_title'
#JL    config.add_index_field solr_name("medium", :stored_searchable), itemprop: 'medium'
#JL    config.add_index_field solr_name("support", :stored_searchable), itemprop: 'support'
#JL    config.add_index_field solr_name("dris_page_no", :stored_searchable), itemprop: 'dris_page_no'
#JL    config.add_index_field solr_name("digital_object_identifier", :stored_searchable), itemprop: 'digital_object_identifier'
#JL    config.add_index_field solr_name("language", :stored_searchable), itemprop: 'inLanguage', link_to_search: solr_name("language", :facetable)
#JL    config.add_index_field solr_name("culture", :stored_searchable), itemprop: 'culture'
#JL    config.add_index_field solr_name("provenance", :stored_searchable), itemprop: 'provenance'
#JL    config.add_index_field solr_name("subject", :stored_searchable), itemprop: 'about', link_to_search: solr_name("subject", :facetable)
#JL    config.add_index_field solr_name("keyword", :stored_searchable), itemprop: 'keywords', link_to_search: solr_name("keyword", :facetable)
   config.add_index_field solr_name("genre", :stored_searchable), itemprop: 'genre'
   config.add_index_field solr_name("identifier", :stored_searchable), itemprop: 'identifier'
   config.add_index_field solr_name("doi", :stored_searchable), itemprop: 'doi'
#JL    config.add_index_field solr_name("identifier", :stored_searchable), helper_method: :index_field_link, field_name: 'identifier'
#JL    config.add_index_field solr_name("location", :stored_searchable), itemprop: 'location', link_to_search: solr_name("location", :facetable)
#JL    config.add_index_field solr_name("rights_statement", :stored_searchable), helper_method: :rights_statement_links
#JL    config.add_index_field solr_name("copyright_status", :stored_searchable), itemprop: 'copyright_status'
#JL    config.add_index_field solr_name("date_modified", :stored_sortable, type: :date), itemprop: 'dateModified', helper_method: :human_readable_date


   #config.add_index_field solr_name("dris_unique", :stored_searchable), itemprop: 'dris_unique'
#JL    config.add_index_field solr_name("folder_number", :stored_searchable), itemprop: 'folder_number'
#JL    config.add_index_field solr_name("sponsor", :stored_searchable), itemprop: 'sponsor'
#JL    config.add_index_field solr_name("bibliography", :stored_searchable), itemprop: 'bibliography'
#JL    config.add_index_field solr_name("contributor", :stored_searchable), itemprop: 'contributor', link_to_search: solr_name("contributor", :facetable)
#JL    config.add_index_field solr_name("proxy_depositor", :symbol), label: "Depositor", helper_method: :link_to_profile
#JL    config.add_index_field solr_name("depositor"), label: "Owner", helper_method: :link_to_profile
#JL    config.add_index_field solr_name("based_near_label", :stored_searchable), itemprop: 'contentLocation', link_to_search: solr_name("based_near_label", :facetable)
#JL    config.add_index_field solr_name("date_uploaded", :stored_sortable, type: :date), itemprop: 'datePublished', helper_method: :human_readable_date
#JL    config.add_index_field solr_name("license", :stored_searchable), helper_method: :license_links
#JL    config.add_index_field solr_name("resource_type", :stored_searchable), label: "Resource Type", link_to_search: solr_name("resource_type", :facetable)
#JL    config.add_index_field solr_name("file_format", :stored_searchable), link_to_search: solr_name("file_format", :facetable)
#JL    config.add_index_field solr_name("embargo_release_date", :stored_sortable, type: :date), label: "Embargo release date", helper_method: :human_readable_date
#JL    config.add_index_field solr_name("lease_expiration_date", :stored_sortable, type: :date), label: "Lease expiration date", helper_method: :human_readable_date

   # solr fields to be displayed in the show (single result) view
   #   The ordering of the field names is the order of the display
   config.add_show_field solr_name("title", :stored_searchable)
   config.add_show_field solr_name("description", :stored_searchable)
   #config.add_show_field solr_name("abstract", :stored_searchable)
   config.add_show_field solr_name("dris_page_no", :stored_searchable)
   config.add_show_field solr_name("copyright_note", :stored_searchable)
   config.add_show_field solr_name("copyright_status", :stored_searchable)
   config.add_show_field solr_name("genre", :stored_searchable)
   config.add_show_field solr_name("digital_object_identifier", :stored_searchable)
   config.add_show_field solr_name("dris_unique", :stored_searchable)
   config.add_show_field solr_name("sponsor", :stored_searchable)
   config.add_show_field solr_name("bibliography", :stored_searchable)
   config.add_show_field solr_name("publisher_location", :stored_searchable)
   config.add_show_field solr_name("support", :stored_searchable)
   config.add_show_field solr_name("medium", :stored_searchable)
   config.add_show_field solr_name("alternative_title", :stored_searchable)
   config.add_show_field solr_name("series_title", :stored_searchable)
   config.add_show_field solr_name("collection_title", :stored_searchable)

   config.add_show_field solr_name("provenance", :stored_searchable)
   config.add_show_field solr_name("culture", :stored_searchable)
   config.add_show_field solr_name("location", :stored_searchable)



   config.add_show_field solr_name("keyword", :stored_searchable)
   config.add_show_field solr_name("subject", :stored_searchable)
   config.add_show_field solr_name("creator", :stored_searchable)
   config.add_show_field solr_name("contributor", :stored_searchable)
   config.add_show_field solr_name("publisher", :stored_searchable)
   config.add_show_field solr_name("based_near_label", :stored_searchable)
   config.add_show_field solr_name("language", :stored_searchable)
   config.add_show_field solr_name("date_uploaded", :stored_searchable)
   config.add_show_field solr_name("date_modified", :stored_searchable)
   config.add_show_field solr_name("date_created", :stored_searchable)
   config.add_show_field solr_name("rights_statement", :stored_searchable)
   config.add_show_field solr_name("license", :stored_searchable)
   config.add_show_field solr_name("resource_type", :stored_searchable), label: "Resource Type"
   config.add_show_field solr_name("format", :stored_searchable)
   config.add_show_field solr_name("identifier", :stored_searchable)
   config.add_show_field solr_name("folder_number", :stored_searchable)

   config.add_show_field solr_name("doi", :stored_searchable)
   config.add_show_field solr_name("biographical_note", :stored_searchable)
   config.add_show_field solr_name("finding_aid", :stored_searchable)
   config.add_show_field solr_name("note", :stored_searchable)
   config.add_show_field solr_name("sub_fond", :stored_searchable)
   config.add_show_field solr_name("arrangement", :stored_searchable)
   config.add_show_field solr_name("issued_with", :stored_searchable)
   config.add_show_field solr_name("physical_extent", :stored_searchable)
   # "fielded" search configuration. Used by pulldown among other places.
   # For supported keys in hash, see rdoc for Blacklight::SearchFields
   #
   # Search fields will inherit the :qt solr request handler from
   # config[:default_solr_parameters], OR can specify a different one
   # with a :qt key/value. Below examples inherit, except for subject
   # that specifies the same :qt as default for our own internal
   # testing purposes.
   #
   # The :key is what will be used to identify this BL search field internally,
   # as well as in URLs -- so changing it after deployment may break bookmarked
   # urls.  A display label will be automatically calculated from the :key,
   # or can be specified manually to be different.
   #
   # This one uses all the defaults set by the solr request handler. Which
   # solr request handler? The one set in config[:default_solr_parameters][:qt],
   # since we aren't specifying it otherwise.
   config.add_search_field('all_fields', label: 'All Fields') do |field|
     all_names = config.show_fields.values.map(&:field).join(" ")
     title_name = solr_name("title", :stored_searchable)
     field.solr_parameters = {
       qf: "#{all_names} file_format_tesim all_text_timv",
       pf: title_name.to_s
     }
   end

   # Now we see how to over-ride Solr request handler defaults, in this
   # case for a BL "search field", which is really a dismax aggregate
   # of Solr search fields.
   # creator, title, description, publisher, date_created,
   # subject, language, resource_type, format, identifier, based_near,
   config.add_search_field('contributor') do |field|
     # solr_parameters hash are sent to Solr as ordinary url query params.

     # :solr_local_parameters will be sent using Solr LocalParams
     # syntax, as eg {! qf=$title_qf }. This is neccesary to use
     # Solr parameter de-referencing like $title_qf.
     # See: http://wiki.apache.org/solr/LocalParams
     solr_name = solr_name("contributor", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('creator') do |field|
     solr_name = solr_name("creator", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('title') do |field|
     solr_name = solr_name("title", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('description') do |field|
     field.label = "Description"
     solr_name = solr_name("description", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('abstract') do |field|
     field.label = "Abstract"
     solr_name = solr_name("abstract", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('dris_page_no') do |field|
     field.label = "Page no"
     solr_name = solr_name("dris_page_no", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('copyright_note') do |field|
     field.label = "Copyright Note"
     solr_name = solr_name("copyright_note", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('copyright_status') do |field|
     field.label = "Copyright Status"
     solr_name = solr_name("copyright_status", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('genre') do |field|
     field.label = "Genre"
     solr_name = solr_name("genre", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('digital_object_identifier') do |field|
     field.label = "Digital Object Identifier"
     solr_name = solr_name("digital_object_identifier", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('dris_unique') do |field|
     field.label = "Dris Unique"
     solr_name = solr_name("dris_unique", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('sponsor') do |field|
     field.label = "Sponsor"
     solr_name = solr_name("sponsor", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('bibliography') do |field|
     field.label = "Bibliography"
     solr_name = solr_name("bibliography", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end


   config.add_search_field('publisher_location') do |field|
     field.label = "Publisher Location"
     solr_name = solr_name("publisher_location", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('support') do |field|
     field.label = "Support"
     solr_name = solr_name("support", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('medium') do |field|
     field.label = "Medium"
     solr_name = solr_name("medium", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('alternative_title') do |field|
     field.label = "Alternative Title"
     solr_name = solr_name("alternative_title", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('series_title') do |field|
     field.label = "Series Title"
     solr_name = solr_name("series_title", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('collection_title') do |field|
     field.label = "Collection Title"
     solr_name = solr_name("collection_title", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('provenance') do |field|
     field.label = "Provenance"
     solr_name = solr_name("provenance", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('culture') do |field|
     field.label = "Culture"
     solr_name = solr_name("culture", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('location') do |field|
     field.label = "Location"
     solr_name = solr_name("location", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end


   config.add_search_field('publisher') do |field|
     solr_name = solr_name("publisher", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('date_created') do |field|
     solr_name = solr_name("created", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('subject') do |field|
     solr_name = solr_name("subject", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('language') do |field|
     solr_name = solr_name("language", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('resource_type') do |field|
     solr_name = solr_name("resource_type", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('format') do |field|
     solr_name = solr_name("format", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('identifier') do |field|
     solr_name = solr_name("id", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('based_near') do |field|
     field.label = "Based Near"
     solr_name = solr_name("based_near_label", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('keyword') do |field|
     solr_name = solr_name("keyword", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('depositor') do |field|
     solr_name = solr_name("depositor", :symbol)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('rights_statement') do |field|
     solr_name = solr_name("rights_statement", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('license') do |field|
     solr_name = solr_name("license", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('folder_number') do |field|
     field.label = "Folder number"
     solr_name = solr_name("folder_number", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('doi') do |field|
     field.label = "DOI"
     solr_name = solr_name("doi", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('biographical_note') do |field|
     field.label = "Biographical Note"
     solr_name = solr_name("biographical_note", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('finding_aid') do |field|
     field.label = "Finding Aid"
     solr_name = solr_name("finding_aid", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('note') do |field|
     field.label = "Note"
     solr_name = solr_name("note", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('sub_fond') do |field|
     field.label = "Sub Fond"
     solr_name = solr_name("sub_fond", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('arrangement') do |field|
     field.label = "Arrangement"
     solr_name = solr_name("arrangement", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('issued_with') do |field|
     field.label = "Issued With"
     solr_name = solr_name("issued_with", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end

   config.add_search_field('physical_extent') do |field|
     field.label = "Physical Extent"
     solr_name = solr_name("physical_extent", :stored_searchable)
     field.solr_local_parameters = {
       qf: solr_name,
       pf: solr_name
     }
   end
   # "sort results by" select (pulldown)
   # label in pulldown is followed by the name of the SOLR field to sort by and
   # whether the sort is ascending or descending (it must be asc or desc
   # except in the relevancy case).
   # label is key, solr field is value
   config.add_sort_field "score desc, #{uploaded_field} desc", label: "relevance"
   config.add_sort_field "#{uploaded_field} desc", label: "date uploaded \u25BC"
   config.add_sort_field "#{uploaded_field} asc", label: "date uploaded \u25B2"
   config.add_sort_field "#{modified_field} desc", label: "date modified \u25BC"
   config.add_sort_field "#{modified_field} asc", label: "date modified \u25B2"
   config.add_sort_field "#{identifier_first_field} desc", label: "Shelf/Reference number \u25BC"
   config.add_sort_field "#{identifier_first_field} asc", label: "Shelf/Reference number \u25B2"


   # If there are more than this many search results, no spelling ("did you
   # mean") suggestion is offered.
   config.spell_max = 5
 end

 # disable the bookmark control from displaying in gallery view
 # Hyrax doesn't show any of the default controls on the list view, so
 # this method is not called in that context.
 def render_bookmarks_control?
   false
 end
end