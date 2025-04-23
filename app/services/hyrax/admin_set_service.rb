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

      yearWiseworkCounts = count_works_from_2020(admin_sets)
      Rails.logger.info "Work Counts from 2020 to #{Time.now.year}: #{yearWiseworkCounts.map { |year, count| "#{count}, #{year}" }.join('; ')}"

      yearWiseFileCounts = count_files_from_2020(admin_sets)
      Rails.logger.info "File Counts from 2020: #{yearWiseFileCounts.map { |year, count| "#{count}, #{year}" }.join('; ')}"

      admin_sets.map do |admin_set|
        SearchResultForWorkCount.new(admin_set, counts[admin_set.id].to_i, file_counts[admin_set.id].to_i)
      end
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

      def count_files_from_2020(admin_sets)
        file_counts_by_year = Hash.new { |hash, key| hash[key] = 0 }
        current_year = Time.now.year
      
        (2020..current_year).each do |year|  # Fixed range from 2020 to now
          admin_sets.each do |admin_set|
            date_query = "date_uploaded_dtsi:[#{year}-01-01T00:00:00Z TO #{year}-12-31T23:59:59Z]"
            query = "{!join from=file_set_ids_ssim to=id}isPartOf_ssim:#{admin_set.id}"
      
            file_results = ActiveFedora::SolrService.instance.conn.get(
              ActiveFedora::SolrService.select_path,
              params: { fq: [query, "has_model_ssim:FileSet", date_query],
                        rows: 0 }
            )
      
            file_counts_by_year[year] += file_results['response']['numFound']
          end
        end
      
        file_counts_by_year
      end
      
      def count_works_from_2020(access, join_field: "isPartOf_ssim")
        work_counts_by_year = Hash.new { |hash, key| hash[key] = 0 }
        current_year = Time.now.year
      
        (2020..current_year).each do |year|
          admin_sets = search_results(access)  # Fetch accessible admin sets
          ids = admin_sets.map(&:id).join(',')
          date_query = "date_uploaded_dtsi:[#{year}-01-01T00:00:00Z TO #{year}-12-31T23:59:59Z]"
          query = "{!terms f=#{join_field}}#{ids}"
      
          results = ActiveFedora::SolrService.instance.conn.get(
            ActiveFedora::SolrService.select_path,
            params: { fq: [query, date_query],
                      rows: 0,
                      'facet.field' => join_field }
          )
      
          counts = results['facet_counts']['facet_fields'][join_field].each_slice(2).to_h
      
          admin_sets.each do |admin_set|
            work_counts_by_year[year] += counts[admin_set.id].to_i
          end
        end
      
        work_counts_by_year
      end
      
      
  end
end
