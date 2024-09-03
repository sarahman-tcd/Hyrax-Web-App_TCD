# app/controllers/pdf_generation_controller.rb

require 'open-uri'
require 'combine_pdf'
require 'prawn'
require 'mini_magick'
require 'rest-client'
require 'fileutils'
require 'rtesseract'
require 'prawn/measurement_extensions'

require 'net/http'
require 'uri'
require 'json'
require 'tempfile'
require 'net/http/post/multipart'

class PdfGenerationController < ApplicationController    
    Encoding.default_external = Encoding::UTF_8
    OCR_SPACE_API_URL = 'https://apipro2.ocr.space/parse/image'.freeze
    API_KEY='DPD8EXN57323X'.freeze
    
    def pdf   
      begin   
        Rails.logger.debug "version 9.0.0 initiated..."
        work_id = params[:file_set_id]         
        ocr_checkbox_val = params[:ocr_checkbox]  
        
        language = params[:language]
        ocr_engine = params[:engine]
        pdf_source = params[:source]
        
        # Update the pdf file every time - only for logged in user
        delete_file(work_id) if user_signed_in?

        # Check if the PDF file already exists - for end user        
        existing_pdf_path = "/digicolapp/datastore/pdf/#{work_id}.pdf"

        if File.exist?(existing_pdf_path) 
          Rails.logger.debug "PDF already exists. Sending existing PDF."

          if ocr_checkbox_val.to_s == "true"
             send_file existing_pdf_path, filename: "#{work_id}_TextSearchable.pdf", type: 'application/pdf', disposition: 'inline'
          else  
            # Send the existing PDF as a download to the user
            send_file existing_pdf_path, filename: "#{work_id}.pdf", type: 'application/pdf', disposition: 'inline'
            return
          end
        end

        # Change the url for LIVE
        dev = 'http://dcdev-solr.tcd.ie:8983/solr/tcd-hyrax/'
        primary = 'http://digcoll-solr01.tcd.ie:8983/solr/tcd-hyrax/'
        secondary = 'http://digcoll-solr02.tcd.ie:8983/solr/tcd-hyrax/'

        # This- Replace dev to primary 
        $solr = RSolr.connect(url: primary) 
        work_response = $solr.get('select', params: { q: "id:#{work_id}" })
        work_data = work_response['response']['docs'][0]        
    
        # Extract relevant data from Solr response
        title = work_data['title_tesim'].present? ? work_data['title_tesim'].first : 'No title available'
        shelf_mark = work_data['identifier_tesim'].present? ? work_data['identifier_tesim'].first : 'No shelf mark available'
        doi = work_data['doi_tesim'].present? ? work_data['doi_tesim'].first : 'No DOI available'
        date_created = work_data['date_created_tesim'].present? ? work_data['date_created_tesim'].first : 'No date created available'        
         # Check if creator and contributor is present, is an array, and not empty
        creator = work_data['creator_tesim'].present? && work_data['creator_tesim'].is_a?(Array) && !work_data['creator_tesim'].empty? ? work_data['creator_tesim'] : ['Not specified']        
        contributor = work_data['contributor_tesim'].present? && work_data['contributor_tesim'].is_a?(Array) && !work_data['contributor_tesim'].empty? ? work_data['contributor_tesim'] : ['Not specified']
          
        folder_numbers = work_data['folder_number_tesim']
        file_set_ids = work_data['file_set_ids_ssim']
        flag=0
                
        if folder_numbers.blank? && file_set_ids.present?
          Rails.logger.debug "folder_number_tesim #{folder_numbers}"
          rn_file_set_id = work_data['file_set_ids_ssim'][1]
          query = "id:#{rn_file_set_id}"
          rn_response = $solr.get('select', params: { q: query })
          rn_file_set_data = rn_response['response']['docs'][0]

          # Check the title_tesim for the second item
          if rn_file_set_data['title_tesim'].first == 'DigitalCollections.jpg'
            # If the title is 'DigitalCollections.jpg', use the first item instead
            rn_file_set_id = work_data['file_set_ids_ssim'][0]

            # Query Solr for the first file set's data
            query = "id:#{rn_file_set_id}"
            rn_response = $solr.get('select', params: { q: query })
            rn_file_set_data = rn_response['response']['docs'][0]
          end


          folder_numbers = rn_file_set_data['folder_number_tesim'].first
          flag=1
        end
        
        if folder_numbers.present? && file_set_ids.present?
          image_names = []
          if flag == 0
            folder_numbers = work_data['folder_number_tesim'].first
          elsif flag == 1
            folder_numbers = folder_numbers
          end
          
          file_set_ids.each do |file_set_id|
            # Construct a Solr query to fetch the label_ssi for the given file_set_id
            query = "id:#{file_set_id}"
            
            # Execute the Solr query
            response = $solr.get('select', params: { q: query })
            # Extract the image name (label_ssi) from the Solr response
            file_set_data = response['response']['docs'].first
            image_name = file_set_data['label_ssi']

            # If there is child work exist
            if (image_name.nil? || image_name.empty?) 
              nested_file_set_ids = file_set_data['file_set_ids_ssim']

              if nested_file_set_ids.present?
                nested_file_set_ids.each do |next_file_set_id|
                  query = "id:#{next_file_set_id}"                  
                  response = $solr.get('select', params: { q: query })
                  next_file_set_data = response['response']['docs'].first
                  imagename = next_file_set_data['label_ssi']
                  image_names << imagename if imagename.present?
                end
              end              
            end    

            # Add the image name to the list if it exists
            image_names << image_name if image_name.present?
          end
    
          # Sort the image names to maintain the image order in the pdf
          image_names.sort!

          if image_names.present?           
            # Construct paths based on folder_numbers and image name            
            folder_path_lo = "/digicolapp/datastore/web/#{folder_numbers}/LO"
            folder_path_hi = "/digicolapp/datastore/web/#{folder_numbers}/HI"
            
            # Redirect to the HI or LO directory based on the image name suffix 
            # If not, redirect based on the existing directory 
            first_image = image_names[0]
            folder_type = if first_image.include?("_HI")
                            'HI'
                          elsif first_image.include?("_LO")
                            'LO'
                          else
                            if File.exist?(folder_path_lo)
                              'LO'
                            else
                              'HI'
                            end
                          end
            
            # paths = image_names.map { |image_name| "/digicolapp/datastore/web/#{folder_numbers}/#{folder_type}/#{image_name}" }            
            paths = image_names.map do |image_name|
              next if image_name == "DigitalCollections.jpg"
              
              "/digicolapp/datastore/web/#{folder_numbers}/#{folder_type}/#{image_name}"
            end.compact

            response.headers['Content-Type'] = 'application/pdf'
            response.headers['Content-Disposition'] = "attachment; filename=\"#{work_id}.pdf\""           

            # Call the method to generate and download the PDF
            generate_and_download_pdf(paths, work_id, title, shelf_mark, doi, creator, contributor, date_created, ocr_checkbox_val )
          else
            # Handle the case where image names could not be retrieved
            Rails.logger.error "Error: Image names could not be retrieved from Solr"
          end
        else
          # Handle the case where required fields are missing in Solr response
          Rails.logger.error "Error: Required fields missing in Solr response"
        end
      
      rescue => e
        backtrace = e.backtrace.first
        Rails.logger.error "Error: #{e.message}, Raised at: #{backtrace}"
      end
    end   
    
    def generate_and_download_pdf(paths, file_set_id, title, shelf_mark, doi, creator, contributor, date_created, ocr_checkbox_val)
      begin
        # Create a new PDF document
        pdf = Prawn::Document.new
    
        # Add a title page
        add_title_page(pdf, title, shelf_mark, doi, creator, contributor, date_created, '/opt/app/TCD-Hyrax-Web-App/tcd-logo-2x.png') 
        pdf.start_new_page
        
        # Initialize a flag to check if any images have been added
        images_added = false
    
        if ocr_checkbox_val.to_s == "true"
          # Initialize text file handling
          text_file_path = "/digicolapp/datastore/pdf/text/#{file_set_id}.txt"
          File.open(text_file_path, 'w') {} # Create an empty text file
        end

        paths.each do |url|
          # Get the image data
          image_data = URI.open(url).read
    
         # Resize and compress the image
          resized_image_data = resize_image(image_data)

          if ocr_checkbox_val.to_s == "true"
            # Save the resized image to a temporary file
            temp_image_path = "/digicolapp/datastore/pdf/temp/#{File.basename(url)}"
            File.open(temp_image_path, 'wb') { |f| f.write resized_image_data }

            # Extract text from the image using rtesseract
            ocr = RTesseract.new(temp_image_path)
            ocr_text = ocr.to_s

            # Write extracted text to the text file
            File.open(text_file_path, 'a') { |f| f.puts ocr_text }
            
            # Delete the temporary image file after extraction
            File.delete(temp_image_path) if File.exist?(temp_image_path)
          end

          # If images haven't been added yet, don't start a new page
          if images_added 
            pdf.start_new_page
          else
            images_added = true
          end

          # Check the dimensions of the image
          image = MiniMagick::Image.read(resized_image_data)
          image_width= image.width
          image_height = image.height

    
          # Add the compressed image to the PDF
          if image_width > image_height && image_width > pdf.bounds.width
            # Landscape image
            pdf.image StringIO.new(resized_image_data), width: pdf.bounds.width, position: :left
          elsif image_height > image_width && image_height > pdf.bounds.height
            # Portrait image
            pdf.image StringIO.new(resized_image_data), height: pdf.bounds.height, position: :center
          else
            # Regular image
            pdf.image StringIO.new(resized_image_data), width: pdf.bounds.width, height: pdf.bounds.height, position: :center
          end
        end
       
        # Save the PDF to a file
        pdf_filename = "#{file_set_id}.pdf"
        pdf_path = "/digicolapp/datastore/pdf/#{pdf_filename}"           
        pdf.render_file(pdf_path)

        if ocr_checkbox_val.to_s == "true"
          ocr_language = params[:language]
          ocr_engine = params[:engine]
          pdf_source = params[:source]
          
          ocr_and_download_searchable_pdf(pdf_path, ocr_language, ocr_engine, pdf_source)
        else    
          send_file pdf_path, filename: pdf_filename, type: 'application/pdf', disposition: 'inline'
        end  
      rescue => e
        backtrace = e.backtrace.first
        Rails.logger.error "Error: #{e.message}, Raised at: #{backtrace}"
      end
    end    

    # Based on the file existence Download PDF will be visible
    def check_pdf_file_exists
      file_set_id = params[:file_set_id]
      @pdf_file_exists = File.exist?("/digicolapp/datastore/pdf/#{file_set_id}.pdf")
    
      respond_to do |format|
        format.json { render json: { pdf_file_exists: @pdf_file_exists } }
      end
    end


    def downloadPdfTextFile
      file_set_id = params[:file_set_id]  
      existing_text_path = "/digicolapp/datastore/pdf/text/#{file_set_id}.txt"

      if File.exist?(existing_text_path) 
          Rails.logger.debug "PDF text file already exists. Sending existing PDF text file."

          # Send the existing PDF text file as a download to the user
          send_file existing_text_path, filename: "#{file_set_id}.txt", type: 'application/text', disposition: 'inline'
      end     
    end
    
    # Check if pdf text file exists
    def pdf_text_file_exists
      file_set_id = params[:file_set_id]
      @text_file_exists = File.exist?("/digicolapp/datastore/pdf/text/#{file_set_id}.txt")
    
      respond_to do |format|
        format.json { render json: { text_file_exists: @text_file_exists } }
      end
    end
    
    
  
    private
  
   def add_title_page(pdf, title, shelf_mark, doi, creator, contributor, date_created, logo_path)
      # Add a UTF-8 compatible font family (Open Sans in this case)
      pdf.font_families.update("OpenSans" => {
        normal: "app/assets/fonts/OpenSans-Regular.ttf",
        bold: "app/assets/fonts/OpenSans-Bold.ttf",
        italic: "app/assets/fonts/OpenSans-RegularItalic.ttf"
      })

      # Use the Open Sans font
      pdf.font "OpenSans"

      # Add your logo at the top left corner
      pdf.image logo_path, position: :left, width: 232, height: 62      
      pdf.move_down 22 # Adjust as needed

      # Add the title
      pdf.font_size 14
      pdf.text title, style: :bold
      pdf.move_down 10

      pdf.font_size 12
      # Add Shelf Mark/Reference Number
      pdf.text "Shelf Mark/Reference Number", style: :bold
      pdf.text "#{shelf_mark}"
      pdf.move_down 10

      # Add DOI
      pdf.text "DOI", style: :bold
      pdf.text "#{doi}"
      pdf.move_down 10

      # Add Creator(s)
      pdf.text "Creator", style: :bold
      creator.each { |c| pdf.text "#{c}" }
      pdf.move_down 10

      # Add Contributor(s)
      pdf.text "Contributor", style: :bold
      contributor.each { |c| pdf.text "#{c}" }
      pdf.move_down 10

      # Add Date Created
      pdf.text "Date", style: :bold
      pdf.text "#{date_created}"
      pdf.move_down 10          

      # Add the fixed text at the bottom center
      fixed_text = "Library of Trinity College Dublin, Digital Collections (https://digitalcollections.tcd.ie/)"
      pdf.fill_color "888888" # Gray color
      pdf.text_box(fixed_text,
                  at: [pdf.bounds.left, pdf.bounds.bottom + 15], # Adjust Y value as needed
                  width: pdf.bounds.width,
                  height: 30,
                  size: 8,
                  align: :center)
                
    end

    def resize_image(image_data)
      image = MiniMagick::Image.read(image_data)
    
      # Get the original dimensions
      original_width = image[:width]
      original_height = image[:height]
    
      # Calculate new dimensions while maintaining aspect ratio
      if original_width > original_height
        new_width = 2000
        new_height = (original_height.to_f / original_width.to_f * 2000).to_i
      else
        new_height = 2000
        new_width = (original_width.to_f / original_height.to_f * 2000).to_i
      end
    
      # Resize the image
      image.resize "#{new_width}x#{new_height}"
    
      # Apply compression
      image.quality 70
    
      # Return the image as binary data
      image.to_blob
    end    

    def delete_file (file_set_id)
      existing_pdf_path = "/digicolapp/datastore/pdf/#{file_set_id}.pdf"
      if File.exist?(existing_pdf_path)
        File.delete(existing_pdf_path)
        
      else
        Rails.logger.debug "PDF File not found."
      end
    end

    def ocr_and_download_searchable_pdf(pdf_path, ocr_language, ocr_engine, pdf_source)
      file_set_id = params[:file_set_id]
      public_pdf_path = Rails.root.join('public', "#{file_set_id}.pdf")
    
      # Copy the PDF file to the public folder
      FileUtils.cp(pdf_path, public_pdf_path)
    
      # Perform OCR using OCR Space API depends on Source Type
      ocr_response = nil
      if pdf_source == "file"
        ocr_response = perform_ocr_file(pdf_path, ocr_language, ocr_engine)
      elsif pdf_source == "url"
        ocr_response = perform_ocr_url(file_set_id, ocr_language, ocr_engine)
      end
    
      if ocr_response['SearchablePDFURL'].present?
        searchable_pdf_url = ocr_response['SearchablePDFURL']
        Rails.logger.debug "searchable_pdf_url #{searchable_pdf_url}"
        # Download the searchable PDF
        downloaded_pdf_path = download_searchable_pdf(searchable_pdf_url, pdf_path)
    
        File.delete(public_pdf_path) if File.exist?(public_pdf_path) 
    
        # Send the downloadable PDF to the user
        pdf_filename = "#{file_set_id}_TextSearchable.pdf" 
        Rails.logger.debug "pdf_filename #{pdf_filename}"
        Rails.logger.debug "downloaded_pdf_path #{downloaded_pdf_path}"
        send_file downloaded_pdf_path, filename: pdf_filename, type: 'application/pdf', disposition: 'inline'
      else
        
        File.delete(public_pdf_path) if File.exist?(public_pdf_path)
    
        Rails.logger.debug "OCR failed or no searchable PDF found."
      end
    end

    # Perform OCR when PDF source is URL
    def perform_ocr_url(file_set_id, ocr_language, ocr_engine)
      # THIS - uncomment the nxt line once in live
      pdf_url="https://digitalcollections.tcd.ie/#{file_set_id}.pdf" 
      # Delete or comment the next one line once in live- THIS
      # pdf_url="https://digitalcollections.tcd.ie/temp.pdf"

      Rails.logger.debug "path_pdf: #{pdf_url}"   

      response = RestClient::Request.execute(method: :post, url: OCR_SPACE_API_URL, payload: {
                                  apikey: API_KEY,
                                  language: ocr_language,
                                  url: pdf_url,
                                  filetype: 'PDF',
                                  isCreateSearchablePdf: true,
                                  isSearchablePdfHideTextLayer: true,
                                  OCREngine: ocr_engine
                                },
                                headers: {
                                  content_type: 'application/pdf'
                                })
                               
      Rails.logger.debug "response: #{response.body}"
      JSON.parse(response.body)
    end

     # Perform OCR when PDF source is FILE
    def perform_ocr_file(pdf_path, ocr_language, ocr_engine)

      uri = URI.parse(OCR_SPACE_API_URL)
     
      request = Net::HTTP::Post::Multipart.new(uri.path,
        {
          'apikey' => API_KEY,
          'language' => ocr_language,
          'isCreateSearchablePdf' => 'true',
          'isSearchablePdfHideTextLayer' => 'true',
          'OCREngine' => ocr_engine,
          'file' => UploadIO.new(pdf_path, 'application/pdf', File.basename(pdf_path)),          
          'filetype' => 'PDF'
        }
      )
  
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      Rails.logger.debug "response: #{response.body}"
      JSON.parse(response.body)
    end
    
    def download_searchable_pdf(url, original_pdf_path)
      # downloaded_pdf_path = original_pdf_path.sub(/\.pdf$/, '.pdf')
      File.open(original_pdf_path, 'wb') do |file|
        file.write RestClient.get(url).body
      end  
      original_pdf_path
    end

  end