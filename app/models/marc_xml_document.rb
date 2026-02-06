class MarcXmlDocument # < Nokogiri::XML::Document
  include MarcXmlStructure
  attr_reader :source_file

  def initialize(marcxml_file)
    #byebug
    @source_file = marcxml_file
    @marcxml = File.open(@source_file) { |f| Nokogiri::XML(f) }
  end

  def ark_id
    #byebug
    @marcxml.xpath("//*[local-name()='controlfield'][@tag='001']").text
  end

  def title
    @marcxml.xpath("//*[local-name()='datafield'][@tag='245']")
  end

  
  def rights_statements
    @marcxml.xpath("//*[local-name()='datafield'][@tag='542']")
  end

  def copyright_status
    @marcxml.xpath("//*[local-name()='datafield'][@tag='542']")
  end

  def copyright_notes
    @marcxml.xpath("//*[local-name()='datafield'][@tag='542']")
  end

  def license
    @marcxml.xpath("//*[local-name()='datafield'][@tag='540']")
  end


  # def rights_statements
  #     @marcxml.xpath("//datafield[@tag='542'][@ind1=' '] | //datafield[@tag='542'][@ind1='1'] ")
  # end

  # def copyright_notes
  #     @marcxml.xpath("//datafield[@tag='542'][@ind1=' '] | //datafield[@tag='542'][@ind1='1'] ")
  # end

  def genres
    @marcxml.xpath("//*[local-name()='datafield'][@tag='655']")
  end

  def abstracts
    @marcxml.xpath("//*[local-name()='datafield'][@tag='520']")
  end

  def identifiers
    @marcxml.xpath("//*[local-name()='datafield'][@tag='534']/*[local-name()='subfield'][@code='o']")
  end

  def locations
    @marcxml.xpath("//*[local-name()='datafield'][@tag='534']/*[local-name()='subfield'][@code='l']")
  end

  def creators
    @marcxml.xpath("//*[local-name()='datafield'][@tag='100'] | //*[local-name()='datafield'][@tag='110'] | //*[local-name()='datafield'][@tag='111'] | //*[local-name()='datafield'][@tag='700'] | //*[local-name()='datafield'][@tag='710'] | //*[local-name()='datafield'][@tag='711']")
  end

  def contributors
    @marcxml.xpath("//*[local-name()='datafield'][@tag='100'] | //*[local-name()='datafield'][@tag='110'] | //*[local-name()='datafield'][@tag='111'] | //*[local-name()='datafield'][@tag='700'] | //*[local-name()='datafield'][@tag='710'] | //*[local-name()='datafield'][@tag='711']")
  end

  def publisher_locations
    @marcxml.xpath("//*[local-name()='datafield'][@tag='264']/*[local-name()='subfield'][@code='a']")
  end

  def publishers
    @marcxml.xpath("//*[local-name()='datafield'][@tag='264']/*[local-name()='subfield'][@code='b']")
  end

  def dates_created
    @marcxml.xpath("//*[local-name()='datafield'][@tag='264']/*[local-name()='subfield'][@code='c']")
  end

  def languages
    @marcxml.xpath("//*[local-name()='datafield'][@tag='041']/*[local-name()='subfield'][@code='a']")
  end

  def related_urls
    @marcxml.xpath("//*[local-name()='datafield'][@tag='545']/*[local-name()='subfield'][@code='u'] | //*[local-name()='datafield'][@tag='555']/*[local-name()='subfield'][@code='u']")
  end

  def sponsors
    @marcxml.xpath("//*[local-name()='datafield'][@tag='536']/*[local-name()='subfield'][@code='a']")
  end

  def subjects_and_keywords
    @marcxml.xpath("//*[local-name()='datafield'][@tag='600'] | //*[local-name()='datafield'][@tag='610'] | //*[local-name()='datafield'][@tag='611'] | //*[local-name()='datafield'][@tag='647'] | //*[local-name()='datafield'][@tag='648'] | //*[local-name()='datafield'][@tag='650'] | //*[local-name()='datafield'][@tag='651']")
  end

  def resource_types
    @marcxml.xpath("//*[local-name()='datafield'][@tag='336']/*[local-name()='subfield'][@code='a']")
  end

  def mediums
    @marcxml.xpath("//*[local-name()='datafield'][@tag='340']/*[local-name()='subfield'][@code='c']")
  end

  def supports
    @marcxml.xpath("//*[local-name()='datafield'][@tag='340']/*[local-name()='subfield'][@code='a'] | //*[local-name()='datafield'][@tag='340']/*[local-name()='subfield'][@code='e']")
  end

  def digital_object_identifier
    @marcxml.xpath("//*[local-name()='datafield'][@tag='019']/*[local-name()='subfield'][@code='e']").text
  end

  def folder_number
    @marcxml.xpath("//*[local-name()='datafield'][@tag='019']/*[local-name()='subfield'][@code='b']").text
  end

  def digital_root_number
    @marcxml.xpath("//*[local-name()='datafield'][@tag='019']/*[local-name()='subfield'][@code='d']").text
  end

  def image_range
    @marcxml.xpath("//*[local-name()='datafield'][@tag='019']/*[local-name()='subfield'][@code='f']").text
  end

  def dris_unique
    @marcxml.xpath("//*[local-name()='controlfield'][@tag='001']").text
  end

  def biographical_notes
    @marcxml.xpath("//*[local-name()='datafield'][@tag='545']")
  end

  def finding_aids
    @marcxml.xpath("//*[local-name()='datafield'][@tag='555']")
  end

  def alternative_titles
    @marcxml.xpath("//*[local-name()='datafield'][@tag='246']")
  end

  def physical_extents
    @marcxml.xpath("//*[local-name()='datafield'][@tag='300']")
  end

  def series_titles
    @marcxml.xpath("//*[local-name()='datafield'][@tag='490'][@ind1='0'] | //*[local-name()='datafield'][@tag='830']")
  end

  def provenances
    @marcxml.xpath("//*[local-name()='datafield'][@tag='561'][@ind1=' '] | //*[local-name()='datafield'][@tag='561'][@ind1='1'] ")
  end

  def bibliographys
    @marcxml.xpath("//*[local-name()='datafield'][@tag='510']/*[local-name()='subfield'][@code='a']")
  end

  def notes
    @marcxml.xpath("//*[local-name()='datafield'][@tag='500']/*[local-name()='subfield'][@code='a'] | //*[local-name()='datafield'][@tag='546']/*[local-name()='subfield'][@code='a']")
  end

  def collection_titles
    @marcxml.xpath("//*[local-name()='datafield'][@tag='773']")
  end

  def sub_fonds
    @marcxml.xpath("//*[local-name()='datafield'][@tag='773'] | //*[local-name()='datafield'][@tag='774']")
  end

  def arrangements
    @marcxml.xpath("//*[local-name()='datafield'][@tag='351']")
  end

  def issued_withs
    @marcxml.xpath("//*[local-name()='datafield'][@tag='501']/*[local-name()='subfield'][@code='a']")
  end

end
