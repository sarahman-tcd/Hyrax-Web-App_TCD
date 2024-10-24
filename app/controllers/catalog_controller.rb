class CatalogController < ApplicationController
  include Hydra::Catalog
  include Hydra::Controller::ControllerBehavior
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

  private

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
