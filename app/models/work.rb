# Generated via
#  `rails generate hyrax:work Work`
class Work < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = WorkIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  # 20-11-2018 JL:

  property :dris_page_no, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#dp')
  property :dris_document_no, predicate: ::RDF::Vocab::DC.identifier
  property :format_duration, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#fd')
  property :format_resolution, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#fr')

  #  29/11/2018: JL - abstract already exists
  #  property :abstract, predicate: ::RDF::Vocab::MODS.abstract

  #  29/11/2018: JL - access condition in Michelle's xls (Expired, Active, etc) is not in her Mods File
  #  JL: copyright status is in BasicMetadata
  property :copyright_holder, predicate: ::RDF::Vocab::DC.rightsHolder

  # this is TGM genre:
  property :genre, predicate: ::RDF::URI.new("http://id.loc.gov/vocabulary/graphicMaterials") do |index|
    index.as :stored_searchable, :facetable
  end

  property :digital_root_number, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#id')
  property :digital_object_identifier, predicate: ::RDF::Vocab::MODS.identifier
  property :dris_unique, predicate: ::RDF::Vocab::MODS.recordIdentifier do |index|
    index.as :stored_searchable, :facetable
  end

  property :language_code, predicate: ::RDF::URI.new('https://www.loc.gov/standards/iso639-2')
  #  JL: language is in BasicMetadata DC11.language

  #  JL: location already exists
  property :location_type, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#lt')
  property :shelf_locator, predicate: ::RDF::Vocab::MODS.locationShelfLocator

  #  JL: contributor alrady exists in BasicMetadata
  # property :contributor, predicate: ::RDF::URI.new('http://id.loc.gov/authorities/names')

  #  JL: Michelle wanted both of these role fiels to link to <name><role><roleTerm>
  property :role_code, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#rc')
  property :role, predicate: ::RDF::URI.new('https://www.loc.gov/standards/sourcelist/relator-role')

  #  JL: how to handle locally created contributor names, role_code and role? Same data as above but different Mods to be output

  property :sponsor, predicate: ::RDF::URI.new('http://www.loc.gov/marc/bibliographic/bd536')

  property :bibliography, predicate: ::RDF::URI.new("https://www.loc.gov/marc/bibliographic/bd504") do |index|
    index.as :stored_searchable, :facetable
  end

  property :conservation_history, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#ch')

  #  JL: date is in BasicMetadata
  #  JL: publsher is in BasicMetadata

  #  JL publisher place and publisher country are both described for MODS.place so merged
  property :publisher_location, predicate: ::RDF::Vocab::MODS.placeOfOrigin

  property :page_number, predicate: ::RDF::Vocab::MODS.partOrder
  property :page_type, predicate: ::RDF::Vocab::MODS.partType

  property :physical_extent, predicate: ::RDF::Vocab::MODS.physicalExtent
  #  JL: can physical_entent replace format_h and format_w?
  #  property :format_h, predicate: ::RDF::Vocab::????
  #  property :format_w, predicate: ::RDF::Vocab::????

  property :support, predicate: ::RDF::Vocab::MODS.physicalForm

  #  JL: medium cant refer to same Mods fields
  #      property :medium, predicate: ::RDF::Vocab::????
  property :medium, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#me')
  property :type_of_work, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#type_of_work')

  #  JL: modification_date is in CoreMetadata
  #  JL: creation_date is in CoreMetadata

  property :related_item_type, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#related_item_type')
  property :related_item_identifier, predicate: ::RDF::Vocab::MODS.relatedItem
  property :related_item_title, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#related_item_title')

  property :subject_lcsh, predicate: ::RDF::Vocab::MODS.subject
  property :subject_local, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#subject_local')
  #  JL: subject is in BasicMetadata
  property :subject_name, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#subject_name')

  #  JL: caption/notes/description is in BasicMetadata

  property :alternative_title, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#alternative_title')
  #  JL: item_title is in CoreMetadata
  property :series_title, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#series_title')
  property :collection_title, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#collection_title')
  property :virtual_collection_title, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#virtual_collection_title')

  #  JL: type_of_resource is in BasicMetadata

  property :provenance, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#provenance')

  #  JL:property :copyright_notice, see rights in BasicMetadata, DC.rights

  property :visibility_flag, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#visibility')
  property :europeana, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#europeana')
  property :solr_flag, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#solr')
  property :culture, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#culture')

  property :county, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#county')
  property :folder_number, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#folder_number')
  property :project_number, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#project_number')
  property :order_no, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#order_no')
  property :total_records, predicate: ::RDF::URI.new('https://digitalcollections.tcd.ie/app/assets/local_vocabulary.html#total_records')

  #  JL: note, in FileMaker can be captured in two places, depending on whether vocab used

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
