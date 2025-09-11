module TcdMetadata
  class MarcXmlRecord < MarcXmlDocument
    def initialize(id, source)
      # JL: The caller sends the whole XML file, so need to just pull marc:record node for current recordIdentifier
      @id = id
      @source = source
      @marcxml = Nokogiri::XML(source)
      
      # Find the specific record that matches our ID
      @elements = @marcxml.xpath("//*[local-name()='record']")
      @elements.each do |elem|
        # Look for the controlfield with tag="001" that contains our ID
        controlfield_001 = elem.xpath(".//*[local-name()='controlfield'][@tag='001']").first
        if controlfield_001 && controlfield_001.text.strip == id
          @marcxml = elem
          break
        end
      end
      
      # If we didn't find the record, raise an error
      if @marcxml.xpath("//*[local-name()='controlfield'][@tag='001']").empty?
        raise StandardError, "Record with ID '#{id}' not found in XML source"
      end
    end

    attr_reader :id, :source

    # local metadata
    ATTRIBUTES = %w[
      source_metadata_identifier
      title
    ].freeze

    def attributes
      ATTRIBUTES.map { |att| [att, send(att)] }.to_h.compact
    end

    def source_metadata_identifier
      ark_id
    end

  end
end