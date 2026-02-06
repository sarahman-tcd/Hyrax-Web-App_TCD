# frozen_string_literal: true

module Hyrax
  # Returns AdminSets that the current user has permission to use.
  class AdminSetService
    attr_reader :context, :search_builder
    class_attribute :default_search_builder
    self.default_search_builder = Hyrax::AdminSetSearchBuilder

    # @param [#repository,#blacklight_config,#current_ability] context
    def initialize(context, search_builder = default_search_builder)
      @context = context
      @search_builder = search_builder
    end

    # @param [Symbol] access :deposit, :read or :edit
    def search_results(access)
      response = context.repository.search(builder(access))
      response.documents
    end

    SearchResultForWorkCount = Struct.new(:admin_set, :work_count, :file_count)

    # This performs a two pass query, first getting the AdminSets
    # and then getting the work and file counts
    # @param [Symbol] access :read or :edit
    # @param join_field [String] how are we joining the admin_set ids (by default "isPartOf_ssim")
    # @return [Array<Hyrax::AdminSetService::SearchResultForWorkCount>] a list with document, then work and file count
    def search_results_with_work_count(access, join_field: "isPartOf_ssim")
      admin_sets = search_results(access)
      ids = admin_sets.map(&:id).join(',')
      query = "{!terms f=#{join_field}}#{ids}"
      results = ActiveFedora::SolrService.instance.conn.get(
        ActiveFedora::SolrService.select_path,
        params: { fq: query,
                  rows: 0,
                  'facet.field' => join_field }
      )
      counts = results['facet_counts']['facet_fields'][join_field].each_slice(2).to_h
      file_counts = count_files(admin_sets)

      work_report = count_works_report(access)
      Rails.logger.info "Work Counts (Last 6 Months): #{work_report[:monthly].map { |date, count| "#{count}, #{date}" }.join('; ')}"
      Rails.logger.info "Work Counts (Last 6 Years): #{work_report[:yearly].map { |year, count| "#{count}, #{year}" }.join('; ')}"

      file_report = count_files_report(admin_sets)
      Rails.logger.info "File Counts (Last 6 Months): #{file_report[:monthly].map { |date, count| "#{count}, #{date}" }.join('; ')}"
      Rails.logger.info "File Counts (Last 6 Years): #{file_report[:yearly].map { |year, count| "#{count}, #{year}" }.join('; ')}"

      admin_sets.map do |admin_set|
        SearchResultForWorkCount.new(admin_set, counts[admin_set.id].to_i, file_counts[admin_set.id].to_i)
      end
    end

    def repository_image_growth_data(access, range_type: 'months', value: 6)
      admin_sets = search_results(access)
      ids = admin_sets.map(&:id).join(',')
      join_query = "{!join from=file_set_ids_ssim to=id}{!terms f=isPartOf_ssim}#{ids}"
      current_time = Time.now.utc
      
      if range_type == 'months'
        start_date = (current_time.beginning_of_month - (value.to_i - 1).months).strftime("%Y-%m-01T00:00:00Z")
        end_date = (current_time.beginning_of_month + 1.month).strftime("%Y-%m-01T00:00:00Z")
        gap = "+1MONTH"
        format = "%Y-%m"
      else
        start_date = (current_time.beginning_of_year - (value.to_i - 1).years).strftime("%Y-01-01T00:00:00Z")
        end_date = (current_time.beginning_of_year + 1.year).strftime("%Y-01-01T00:00:00Z")
        gap = "+1YEAR"
        format = "%Y"
      end

      solr_params = {
        fq: [join_query, "has_model_ssim:FileSet"],
        rows: 0,
        facet: true,
        'facet.range' => 'system_create_dtsi',
        'facet.range.start' => start_date,
        'facet.range.end' => end_date,
        'facet.range.gap' => gap
      }

      results = ActiveFedora::SolrService.instance.conn.get(ActiveFedora::SolrService.select_path, params: solr_params)
      facet_counts = results['facet_counts']['facet_ranges']['system_create_dtsi']['counts']
      
      data = []
      facet_counts.each_slice(2) do |date_str, count|
        label = Time.parse(date_str).strftime(format)
        data << { y: label, a: count }
      end
      data
    end

    def repository_object_growth_data(access, range_type: 'months', value: 6)
      admin_sets = search_results(access)
      ids = admin_sets.map(&:id).join(',')
      work_query = "{!terms f=isPartOf_ssim}#{ids}"
      collection_query = "has_model_ssim:Collection"
      current_time = Time.now.utc

      if range_type == 'months'
        start_date = (current_time.beginning_of_month - (value.to_i - 1).months).strftime("%Y-%m-01T00:00:00Z")
        end_date = (current_time.beginning_of_month + 1.month).strftime("%Y-%m-01T00:00:00Z")
        gap = "+1MONTH"
        format = "%Y-%m"
      else
        start_date = (current_time.beginning_of_year - (value.to_i - 1).years).strftime("%Y-01-01T00:00:00Z")
        end_date = (current_time.beginning_of_year + 1.year).strftime("%Y-01-01T00:00:00Z")
        gap = "+1YEAR"
        format = "%Y"
      end

      common_params = {
        rows: 0,
        facet: true,
        'facet.range' => 'system_create_dtsi',
        'facet.range.start' => start_date,
        'facet.range.end' => end_date,
        'facet.range.gap' => gap
      }

      # Query for Works
      work_results = ActiveFedora::SolrService.instance.conn.get(
        ActiveFedora::SolrService.select_path,
        params: common_params.merge(fq: [work_query])
      )
      work_counts = work_results['facet_counts']['facet_ranges']['system_create_dtsi']['counts']

      # Query for Collections
      collection_results = ActiveFedora::SolrService.instance.conn.get(
        ActiveFedora::SolrService.select_path,
        params: common_params.merge(fq: [collection_query])
      )
      collection_counts = collection_results['facet_counts']['facet_ranges']['system_create_dtsi']['counts']

      data = []
      work_counts.each_slice(2).with_index do |(date_str, work_count), index|
        collection_count = collection_counts[index * 2 + 1]
        label = Time.parse(date_str).strftime(format)
        data << { y: label, a: work_count, b: collection_count }
      end
      data
    end

    private

      # @param [Symbol] access :read or :edit
      def builder(access)
        search_builder.new(context, access).rows(100)
      end

      # Count number of files from admin set works
      # @param [Array] AdminSets to count files in
      # @return [Hash] admin set id keys and file count values
      def count_files(admin_sets)
        file_counts = Hash.new(0)
        admin_sets.each do |admin_set|
          query = "{!join from=file_set_ids_ssim to=id}isPartOf_ssim:#{admin_set.id}"
          file_results = ActiveFedora::SolrService.instance.conn.get(
            ActiveFedora::SolrService.select_path,
            params: { fq: [query, "has_model_ssim:FileSet"],
                      rows: 0 }
          )
          file_counts[admin_set.id] = file_results['response']['numFound']
        end
        file_counts
      end

      def count_files_report(admin_sets)
        report = { monthly: {}, yearly: {} }
        current_time = Time.now.utc
        ids = admin_sets.map(&:id).join(',')
        # Join from Works (matching AdminSet) to FileSets
        join_query = "{!join from=file_set_ids_ssim to=id}{!terms f=isPartOf_ssim}#{ids}"

        # Last 6 months
        (0..5).reverse_each do |i|
          date = current_time.beginning_of_month - i.months
          start_date = date.strftime("%Y-%m-01T00:00:00Z")
          end_date = (date + 1.month).strftime("%Y-%m-01T00:00:00Z")
          month_label = date.strftime("%Y-%m")
          
          date_query = "system_create_dtsi:[#{start_date} TO #{end_date}}"
          file_results = ActiveFedora::SolrService.instance.conn.get(
            ActiveFedora::SolrService.select_path,
            params: { fq: [join_query, "has_model_ssim:FileSet", date_query], rows: 0 }
          )
          report[:monthly][month_label] = file_results['response']['numFound']
        end

        # Last 6 years
        current_year = current_time.year
        ((current_year - 5)..current_year).each do |year|
          start_date = "#{year}-01-01T00:00:00Z"
          end_date = "#{year + 1}-01-01T00:00:00Z"
          date_query = "system_create_dtsi:[#{start_date} TO #{end_date}}"
          file_results = ActiveFedora::SolrService.instance.conn.get(
            ActiveFedora::SolrService.select_path,
            params: { fq: [join_query, "has_model_ssim:FileSet", date_query], rows: 0 }
          )
          report[:yearly][year] = file_results['response']['numFound']
        end
        report
      end

      def count_works_report(access, join_field: "isPartOf_ssim")
        report = { monthly: {}, yearly: {} }
        current_time = Time.now.utc
        admin_sets = search_results(access)
        ids = admin_sets.map(&:id).join(',')
        query = "{!terms f=#{join_field}}#{ids}"

        # Last 6 months
        (0..5).reverse_each do |i|
          date = current_time.beginning_of_month - i.months
          start_date = date.strftime("%Y-%m-01T00:00:00Z")
          end_date = (date + 1.month).strftime("%Y-%m-01T00:00:00Z")
          month_label = date.strftime("%Y-%m")
          
          date_query = "system_create_dtsi:[#{start_date} TO #{end_date}}"
          results = ActiveFedora::SolrService.instance.conn.get(
            ActiveFedora::SolrService.select_path,
            params: { fq: [query, date_query], rows: 0, 'facet.field' => join_field }
          )
          counts = results['facet_counts']['facet_fields'][join_field].each_slice(2).to_h
          report[:monthly][month_label] = admin_sets.sum { |as| counts[as.id].to_i }
        end

        # Last 6 years
        current_year = current_time.year
        ((current_year - 5)..current_year).each do |year|
          start_date = "#{year}-01-01T00:00:00Z"
          end_date = "#{year + 1}-01-01T00:00:00Z"
          date_query = "system_create_dtsi:[#{start_date} TO #{end_date}}"
          results = ActiveFedora::SolrService.instance.conn.get(
            ActiveFedora::SolrService.select_path,
            params: { fq: [query, date_query], rows: 0, 'facet.field' => join_field }
          )
          counts = results['facet_counts']['facet_fields'][join_field].each_slice(2).to_h
          report[:yearly][year] = admin_sets.sum { |as| counts[as.id].to_i }
        end
        report
      end

      
  end
end
