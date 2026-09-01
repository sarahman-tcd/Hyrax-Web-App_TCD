# Generated via
#  `rails generate hyrax:work Folio`
class FolioIndexer < Hyrax::WorkIndexer
  # This indexes the default metadata. You can remove it if you want to
  # provide your own metadata and indexing.
  include Hyrax::IndexesBasicMetadata

  # Fetch remote labels for based_near. You can remove this if you don't want
  # this behavior
  # include Hyrax::IndexesLinkedMetadata

  # Truncate string fields so values don't exceed Solr's 32,766-byte term limit
  # when copied to the suggest field via copyField.
  SOLR_MAX_TERM_BYTES = 30_000

  def generate_solr_document
    super.tap do |solr_doc|
      # Check if abstract was truncated so the show page can offer a PDF download
      abstract_val = solr_doc['abstract_tesim']
      if abstract_val.is_a?(Array)
        solr_doc['abstract_truncated_bsi'] = abstract_val.any? { |v| v.is_a?(String) && v.bytesize > SOLR_MAX_TERM_BYTES }
      elsif abstract_val.is_a?(String)
        solr_doc['abstract_truncated_bsi'] = abstract_val.bytesize > SOLR_MAX_TERM_BYTES
      end

      solr_doc.each do |key, value|
        if value.is_a?(Array)
          solr_doc[key] = value.map do |val|
            if val.is_a?(String) && val.bytesize > SOLR_MAX_TERM_BYTES
              val.byteslice(0, SOLR_MAX_TERM_BYTES).scrub('')
            else
              val
            end
          end
        elsif value.is_a?(String) && value.bytesize > SOLR_MAX_TERM_BYTES
          solr_doc[key] = value.byteslice(0, SOLR_MAX_TERM_BYTES).scrub('')
        end
      end
    end
  end
end
