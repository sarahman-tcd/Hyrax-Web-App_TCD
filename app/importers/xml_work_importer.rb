class XmlWorkImporter

  # TODO : Input params list to be extended
  # TODO : Check all fields are present and populated/deduplicated properly
  # TODO : Run this offline? What happens to credentials then?
  # TODO : Allow Work or Collection to be parent_type
  # TODO : Validation, don't crash if file missing
  # TODO : Need to add logs. I want a list of Works, and their IDs to be output
  # TODO : Tidy up

  # JL : 06/02/2019 Michelle asked me to remove deduplication for the following fields:
  #   Subject
  #   Language
  #   Identifier
  #   Date created
  #   Copyright status
  #   Medium
  #   Support
  #   Collection title
  #   Provenance
  #   Culture
  #   Description

  def initialize(file, parent = '000000000', parent_type = 'no_parent', sub_folder = '', base_folder = 'public/data/ingest/')
    @file = file
    @user = ::User.batch_user
    @parent = parent
    @parent_type = parent_type
    @base_folder = base_folder
    @sub_folder = sub_folder

    if !@sub_folder.blank?
      @sub_folder = @sub_folder + '/'
    end

    @file_path = base_folder + @sub_folder + file
  end

  require 'nokogiri'
  require 'open-uri'

  def import

      # byebug
      admin_set_id =  AdminSet.find_or_create_default_admin_set_id

      owner_rec = Work.new
      if @parent_type == "work"
        begin
          owner_rec = Work.find(@parent)
        rescue

        end
      end

      # Fetch and parse HTML document
      #doc = Nokogiri::XML(open("spec/fixtures/Named_Collection_Example_PARTS_RECORDS_v3.6_20181207.xml"))
      doc = Nokogiri::XML(open(@file_path))
      puts "### Search for nodes by xpath"
      doc.xpath("//xmlns:ROW").each do |link|
        work = Work.new
        work.depositor = @user.email

        link.xpath("xmlns:Title").each do |aTitle|
          if !aTitle.content.blank?
            work.title = [aTitle.content]
          end
        end

        # folder_number -> ProjectName
        link.xpath("xmlns:ProjectName").each do |projectName|
          if !projectName.content.blank?
            work.folder_number = [projectName.content]
          end
        end

        # contributor -> AttributedArtist
        link.xpath("xmlns:AttributedArtist").each do |anArtist|
          if !anArtist.content.blank?
            anArtist.xpath("xmlns:DATA").each do |individual|
              if !(owner_rec.contributor.include?(individual.content))
                work.contributor.push(individual.content)
              end
            end
          end
        end

        # creator -> AttributedArtistCalculation
        link.xpath("xmlns:AttributedArtistCalculation").each do |anArtist|
          if !anArtist.content.blank?
            anArtist.xpath("xmlns:DATA").each do |individual|

              # parse each AttributedArtistCalculation on ';' expecting 3 data fields
              indivArtistCalc = individual.content
              indivParts = indivArtistCalc.split(';')

              name = ""
              role = ""
              dataToIngest = ""
              # loop through the sub array and check the key before choosing the value
              indivParts.each do | indivBlob |
                # parse the part with ':' to get key/value pair
                calcVal = indivBlob.split(': ')

                if calcVal.count > 1
                  if calcVal[0] == 'AttributedArtistRole'
                    role = calcVal[1]
                  else if calcVal[0] == ' Attributed Artist'
                         name = calcVal[1]
                       end
                  end
                end
              end

              dataToIngest = name + ', ' + role
              if !dataToIngest.blank?
                work.creator.push(dataToIngest)
              end

            end
          end
        end

        # genre -> SubjectTMG
        link.xpath("xmlns:SubjectTMG").each do |subjects|
          if !subjects.content.blank?
            subjects.xpath("xmlns:DATA").each do |aSubject|
              work.genre.push(aSubject.content)
            end
          end
        end

        # rights_statement -> CopyrightStatus
        # link.xpath("xmlns:CopyrightStatus").each do |statuses|
        #   if !statuses.content.blank?
        #     statuses.xpath("xmlns:DATA").each do |aStatus|
        #       work.rights_statement.push(aStatus.content)
        #     end
        #   end
        # end
        work.rights_statement = ["http://rightsstatements.org/vocab/NKC/1.0/"]

        # abstract
        link.xpath("xmlns:Abstract").each do |abstract|
          if !abstract.content.blank?

              if (abstract.content.length > 200)
                work.description = [(abstract.content.slice(0..200) + '...')]
              else
                 work.description = [abstract.content]
              end
              work.abstract = [abstract.content]

          end
        end

        # publisher
        link.xpath("xmlns:Publisher").each do |publisher|
          if !publisher.content.blank?
            if !(owner_rec.publisher.include?(publisher.content)) then
              work.publisher = [publisher.content]
            end
          end
        end

        # date created
        link.xpath("xmlns:DateCalculation").each do |calcDates|
          if !calcDates.content.blank?
            crArray = Array.new(3)
            calcDates.xpath("xmlns:DATA").each do |aCalcDate|
              aCalcDate.content = aCalcDate.content.sub('DateType: ', '')
              aCalcDate.content = aCalcDate.content.sub('Day: ', '')
              aCalcDate.content = aCalcDate.content.sub(' A.D.', '')
              # input date order is random so need to tidy it up so start end before end date.
              # element[2] is safety net in case input format not what we expect.

              if aCalcDate.content.include?("start")
                crArray[0] = aCalcDate.content
              else if aCalcDate.content.include?("end")
                      crArray[1] = aCalcDate.content
                   else crArray[2] = aCalcDate.content
                   end
              end
            end
            # remove any null elements
            crArray = crArray.compact
            dCre = ""
            crArray.each do | cr |
               dCre += cr + " "
            end
            work.date_created.push(dCre)
          end
        end

        # subject
        # link.xpath("xmlns:SubjectTMG").each do |subjects|
        #  if !subjects.content.blank?
        #    subjects.xpath("xmlns:DATA").each do |aSubject|
        #      if !(owner_rec.subject.include?(aSubject.content))
        #         work.subject.push(aSubject.content)
        #      end
        #    end
        #  end
        # end

        # language
        link.xpath("xmlns:Language").each do |languages|
          if !languages.content.blank?
            languages.xpath("xmlns:DATA").each do |aLanguage|
               work.language.push(aLanguage.content)
            end
          end
        end

        # identifier  -> CatNo
        #link.xpath("xmlns:CatNo").each do |catno|
        #  if !catno.content.blank?
        #     if !(owner_rec.identifier.include?(catno.content)) then
        #       work.identifier = [catno.content]
        #     end
        #  end
        # end

        # location
        link.xpath("xmlns:Location").each do |location|
          if !location.content.blank?
            location.xpath("xmlns:DATA").each do |aLocation|
              if !(owner_rec.location.include?(aLocation.content))
                 work.location.push(aLocation.content)
              end
            end
          end
        end

        # related_url
        # TODO:

        # source
        # TODO:

        # resource_type
        link.xpath("xmlns:Type").each do |aType|
          if !aType.content.blank?
            if !(owner_rec.resource_type.include?(aType.content)) then
               work.resource_type = [aType.content]
            end
          end
        end

        # genre -> TypeOfWork
        # JL : 07/02/2019 Remove at Work level for Michelle
        #link.xpath("xmlns:TypeOfWork").each do |aTypeOfWork|
        #  if !aTypeOfWork.content.blank?
        #     if !(owner_rec.genre.include?(aTypeOfWork.content)) then
        #        work.genre.push(aTypeOfWork.content)
        #     end
        #  end
        #end

        # bibliography
        link.xpath("xmlns:Bibliography").each do |aBibliography|
          if !aBibliography.content.blank?
             if !(owner_rec.bibliography.include?(aBibliography.content)) then
                work.bibliography = [aBibliography.content]
             end
          end
        end

        # dris_page_no
        #link.xpath("xmlns:DrisPageNo").each do |aDrisPageNo|
        #  if !aDrisPageNo.content.blank?
        #     if !(owner_rec.dris_page_no.include?(aDrisPageNo.content)) then
        #       work.dris_page_no = [aDrisPageNo.content]
        #     end
        #  end
        #end

        # dris_document_no
        link.xpath("xmlns:DrisDocumentNo").each do |aDrisDocumentNo|
          if !aDrisDocumentNo.content.blank?
             if !(owner_rec.dris_document_no.include?(aDrisDocumentNo.content)) then
                work.dris_document_no = [aDrisDocumentNo.content]
             end
          end
        end

        # dris_unique
        link.xpath("xmlns:DrisUnique").each do |aDrisUnique|
          if !aDrisUnique.content.blank?
            if !(owner_rec.dris_unique.include?(aDrisUnique.content)) then
               work.dris_unique = [aDrisUnique.content]
            end
          end
        end

        # format_duration
        link.xpath("xmlns:FormatDur").each do |aFormatDuration|
          if !aFormatDuration.content.blank?
            if !(owner_rec.format_duration.include?(aFormatDuration.content)) then
               work.format_duration = [aFormatDuration.content]
            end
          end
        end

        # format_resolution
        link.xpath("xmlns:FormatResolution").each do |aFormatResolution|
          if !aFormatResolution.content.blank?
            if !(owner_rec.format_resolution.include?(aFormatResolution.content)) then
               work.format_resolution = [aFormatResolution.content]
            end
          end
        end

        # copyright_status
        link.xpath("xmlns:CopyrightHolder").each do |copyrightHolders|
          if !copyrightHolders.content.blank?
            copyrightHolders.xpath("xmlns:DATA").each do |aCopyrightHolder|
               work.copyright_status.push(aCopyrightHolder.content)
            end
          end
        end

        # copyright_note
        link.xpath("xmlns:CopyrightNotes").each do |copyrightNotes|
          if !copyrightNotes.content.blank?
            copyrightNotes.xpath("xmlns:DATA").each do |aCopyrightNote|
               if !(owner_rec.copyright_note.include?(aCopyrightNote.content))
                  work.copyright_note.push(aCopyrightNote.content)
               end
            end
          end
        end

        # digital_root_number -> CatNo
        link.xpath("xmlns:CatNo").each do |aDigitalRootNumber|
          if !aDigitalRootNumber.content.blank?
            if !(owner_rec.digital_root_number.include?(aDigitalRootNumber.content)) then
               work.digital_root_number = [aDigitalRootNumber.content]
            end
          end
        end

        imageName = ' '
        # digital_object_identifier -> DRISPhotoID
        link.xpath("xmlns:DRISPhotoID").each do |aDigitalObjectId|
          if !aDigitalObjectId.content.blank?
            imageName = aDigitalObjectId.content
          end
        end

        imageFileName = imageName + "_LO.jpg"
        # imageLocation = "spec/fixtures/" + imageFileName
        imageLocation = @base_folder + @sub_folder + imageFileName

        # language_code -> LanguageTermCode
        #link.xpath("xmlns:LanguageTermCode").each do |languageCodes|
        #  if !languageCodes.content.blank?
        #    languageCodes.xpath("xmlns:DATA").each do |aLanguageCode|
        #      if !(owner_rec.language_code.include?(aLanguageCode.content))
        #         work.language_code.push(aLanguageCode.content)
        #      end
        #    end
        #  end
        #end

        # location_type -> LocationType
        link.xpath("xmlns:LocationType").each do |locationTypes|
          if !locationTypes.content.blank?
            locationTypes.xpath("xmlns:DATA").each do |aLocationType|
              if !(owner_rec.location_type.include?(aLocationType.content))
                 work.location_type.push(aLocationType.content)
              end
            end
          end
        end

        # shelf_locator -> Citation
        link.xpath("xmlns:Citation").each do |aCitation|
          if !aCitation.content.blank?
             work.identifier = [aCitation.content]
          end
        end

        # role_code -> AttributedArtistRoleCode
        #link.xpath("xmlns:AttributedArtistRoleCode").each do |roleCodes|
        #  if !roleCodes.content.blank?
        #    roleCodes.xpath("xmlns:DATA").each do |aRoleCode|
        #      if !(owner_rec.role_code.include?(aRoleCode.content))
        #         work.role_code.push(aRoleCode.content)
        #      end
        #    end
        #  end
        #end

        # role -> AttributedArtistRole
        #link.xpath("xmlns:AttributedArtistRole").each do |roles|
        #  if !roles.content.blank?
        #    roles.xpath("xmlns:DATA").each do |aRole|
        #      if !(owner_rec.role.include?(aRole.content))
        #         work.role.push(aRole.content)
        #      end
        #    end
        #  end
        #end

        # sponsor -> Sponsor
        link.xpath("xmlns:Sponsor").each do |aSponsor|
          if !aSponsor.content.blank?
            if !(owner_rec.sponsor.include?(aSponsor.content)) then
               work.sponsor.push(aSponsor.content)
            end
          end
        end

        # conservation_history -> Introduction
        link.xpath("xmlns:Introduction").each do |aConsHist|
          if !aConsHist.content.blank?
            if !(owner_rec.conservation_history.include?(aConsHist.content)) then
               work.conservation_history.push(aConsHist.content)
            end
          end
        end

        # publisher_location -> PublisherCity; PublisherCountry
        link.xpath("xmlns:PublisherCity").each do |aPublisherLoc|
          if !aPublisherLoc.content.blank?
            if !(owner_rec.publisher_location.include?(aPublisherLoc.content)) then
               work.publisher_location.push(aPublisherLoc.content)
            end
          end
        end
        link.xpath("xmlns:PublisherCountry").each do |aPublisherLoc|
          if !aPublisherLoc.content.blank?
            if !(owner_rec.publisher_location.include?(aPublisherLoc.content)) then
               work.publisher_location.push(aPublisherLoc.content)
            end
          end
        end

        # page_number -> PageNo; PageNoB
        link.xpath("xmlns:PageNo").each do |aPageNo|
          if !aPageNo.content.blank?
            if !(owner_rec.page_number.include?(aPageNo.content)) then
               work.page_number.push(aPageNo.content)
            end
          end
        end
        link.xpath("xmlns:PageNoB").each do |aPageNo|
          if !aPageNo.content.blank?
            if !(owner_rec.page_number.include?(aPageNo.content)) then
               work.page_number.push(aPageNo.content)
            end
          end
        end

        # page_type -> PageType; PageTypeB
        link.xpath("xmlns:PageType").each do |aPageType|
          if !aPageType.content.blank?
            if !(owner_rec.page_type.include?(aPageType.content)) then
               work.page_type.push(aPageType.content)
            end
          end
        end
        link.xpath("xmlns:PageTypeB").each do |aPageType|
          if !aPageType.content.blank?
            if !(owner_rec.page_type.include?(aPageType.content)) then
               work.page_type.push(aPageType.content)
            end
          end
        end

        # physical_extent -> FormatW
        link.xpath("xmlns:FormatW").each do |aPhysicalExtent|
          if !aPhysicalExtent.content.blank?
            if !(owner_rec.physical_extent.include?(aPhysicalExtent.content)) then
               work.physical_extent.push(aPhysicalExtent.content)
            end
          end
        end

        # support and medium are mapped in reverse in XML
        link.xpath("xmlns:Medium").each do |supports|
          if !supports.content.blank?
            supports.xpath("xmlns:DATA").each do |aSupport|
               work.support.push(aSupport.content)
            end
          end
        end

        # medium and support are mapped in reverse in XML
        link.xpath("xmlns:Support").each do |mediums|
          if !mediums.content.blank?
            mediums.xpath("xmlns:DATA").each do |aMedium|
               work.medium.push(aMedium.content)
            end
          end
        end

        # type_of_work
        #link.xpath("xmlns:TypeOfWork").each do |aType|
        #  if !aType.content.blank?
        #    if !(owner_rec.type_of_work.include?(aType.content)) then
        #       work.type_of_work.push(aType.content)
        #    end
        #  end
        #end

        # related_item_type
        link.xpath("xmlns:RelatedItemType").each do |relatedItemTypes|
          if !relatedItemTypes.content.blank?
            relatedItemTypes.xpath("xmlns:DATA").each do |aRelatedItemType|
              if !(owner_rec.related_item_type.include?(aRelatedItemType.content))
                 work.related_item_type.push(aRelatedItemType.content)
              end
            end
          end
        end

        # related_item_identifier
        link.xpath("xmlns:RelatedItemIdentifier").each do |relatedItemIdentifier|
          if !relatedItemIdentifier.content.blank?
            relatedItemIdentifier.xpath("xmlns:DATA").each do |aRelatedItemIdentifier|
              if !(owner_rec.related_item_identifier.include?(aRelatedItemIdentifier.content))
                 work.related_item_identifier.push(aRelatedItemIdentifier.content)
              end
            end
          end
        end

        # related_item_title
        link.xpath("xmlns:RelatedItemTitle").each do |relatedItemTitle|
          if !relatedItemTitle.content.blank?
            relatedItemTitle.xpath("xmlns:DATA").each do |aRelatedItemTitle|
              if !(owner_rec.related_item_title.include?(aRelatedItemTitle.content))
                 work.related_item_title.push(aRelatedItemTitle.content)
              end
            end
          end
        end

        # subject_lcsh -> SubjectLCSH
        link.xpath("xmlns:SubjectLCSH").each do |subjects|
          if !subjects.content.blank?
            subjects.xpath("xmlns:DATA").each do |aSubject|
               work.subject.push(aSubject.content)
            end
          end
        end

        # subject_local -> OpenKeyword
        link.xpath("xmlns:OpenKeyword").each do |subjects|
          if !subjects.content.blank?
            subjects.xpath("xmlns:DATA").each do |aSubject|
              if !(owner_rec.keyword.include?(aSubject.content))
                 work.keyword.push(aSubject.content)
              end
            end
          end
        end

        # subject_name -> LCSubjectNames
        link.xpath("xmlns:LCSubjectNames").each do |subjects|
          if !subjects.content.blank?
            subjects.xpath("xmlns:DATA").each do |aSubject|
               work.subject.push(aSubject.content)
            end
          end
        end

        # alternative_title -> OtherTitle
        link.xpath("xmlns:OtherTitle").each do |titles|
          if !titles.content.blank?
            titles.xpath("xmlns:DATA").each do |aTitle|
              if !(owner_rec.alternative_title.include?(aTitle.content))
                 work.alternative_title.push(aTitle.content)
              end
            end
          end
        end

        # series_title -> SeriesReportNo
        link.xpath("xmlns:SeriesReportNo").each do |titles|
          if !titles.content.blank?
            titles.xpath("xmlns:DATA").each do |aTitle|
              if !(owner_rec.series_title.include?(aTitle.content))
                 work.series_title.push(aTitle.content)
              end
            end
          end
        end

        # collection_title -> TitleLargerEntity
        link.xpath("xmlns:TitleLargerEntity").each do |aTitle|
          if !aTitle.content.blank?
             work.collection_title.push(aTitle.content)
          end
        end

        # virtual_collection_title -> TitleLargerEntity2
        link.xpath("xmlns:TitleLargerEntity2").each do |aTitle|
          if !aTitle.content.blank?
            if !(owner_rec.virtual_collection_title.include?(aTitle.content)) then
               work.virtual_collection_title.push(aTitle.content)
            end
          end
        end

        # provenance
        link.xpath("xmlns:Provenance").each do |aProvenance|
          if !aProvenance.content.blank?
             work.provenance.push(aProvenance.content)
          end
        end

        # visibility_flag
        link.xpath("xmlns:Visibility").each do |visibilityFlag|
          if !visibilityFlag.content.blank?
            if !(owner_rec.visibility_flag.include?(visibilityFlag.content)) then
               work.visibility_flag.push(visibilityFlag.content)
            end
          end
        end

        # europeana
        link.xpath("xmlns:Europeana").each do |europeanaFlag|
          if !europeanaFlag.content.blank?
            if !(owner_rec.europeana.include?(europeanaFlag.content)) then
               work.europeana.push(europeanaFlag.content)
            end
          end
        end

        # solr_flag -> Image
        link.xpath("xmlns:Image").each do |imageFlag|
          if !imageFlag.content.blank?
            if !(owner_rec.solr_flag.include?(imageFlag.content)) then
               work.solr_flag.push(imageFlag.content)
            end
          end
        end

        # culture -> Culture
        link.xpath("xmlns:Culture").each do |cultures|
          if !cultures.content.blank?
            cultures.xpath("xmlns:DATA").each do |aCulture|
               work.culture.push(aCulture.content)
            end
          end
        end

        # county -> CALM
        link.xpath("xmlns:CALM").each do |calmRef|
          if !calmRef.content.blank?
            if !(owner_rec.county.include?(calmRef.content)) then
               work.county.push(calmRef.content)
            end
          end
        end

        # project_number
        link.xpath("xmlns:ProjectNo").each do |projNo|
          if !projNo.content.blank?
            if !(owner_rec.project_number.include?(projNo.content)) then
               work.project_number.push(projNo.content)
            end
          end
        end

        # order_no -> LCN
        link.xpath("xmlns:LCN").each do |orderNo|
          if !orderNo.content.blank?
            if !(owner_rec.order_no.include?(orderNo.content)) then
               work.order_no.push(orderNo.content)
            end
          end
        end

        # total_records
        link.xpath("xmlns:PageTotal").each do |totalRecs|
          if !totalRecs.content.blank?
            if !(owner_rec.total_records.include?(totalRecs.content)) then
               work.total_records.push(totalRecs.content)
            end
          end
        end

        work.admin_set_id = admin_set_id
        #byebug

        work_binary = File.open("#{imageLocation}")
        uploaded_file = Hyrax::UploadedFile.create(user: @user, file: work_binary)
        attributes_for_actor = { uploaded_files: [uploaded_file.id] }
        env = Hyrax::Actors::Environment.new(work, ::Ability.new(@user), attributes_for_actor)
        Hyrax::CurationConcern.actor.create(env)

        work.save

        if !owner_rec.id.blank? && owner_rec.id != '000000000'
           #byebug
           owner_rec.members << work
           owner_rec.ordered_members << work
           owner_rec.save

        end

      end
  end
end
