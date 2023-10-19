# app/controllers/pdf_generation_controller.rb

require 'open-uri'
require 'combine_pdf'
require 'prawn'
require 'mini_magick'
require 'rtesseract'
require 'tempfile' 


class PdfGenerationController < ApplicationController    
    Encoding.default_external = Encoding::UTF_8
    
    def pdf   
      begin   
        Rails.logger.debug "version 8.0.4 initiated..."
        work_id = params[:file_set_id]        
        ocr_checkbox_val = params[:ocr_checkbox]      

        # Update the pdf file every time - logged in user
        delete_file(work_id) if user_signed_in?

        # Check if the PDF file already exists - for end user        
        existing_pdf_path = "/digicolapp/datastore/pdf/#{work_id}.pdf"
        if File.exist?(existing_pdf_path)
          Rails.logger.debug "PDF already exists. Sending existing PDF."

          # Send the existing PDF as a download to the user
          send_file existing_pdf_path, filename: "#{work_id}.pdf", type: 'application/pdf', disposition: 'inline'
          return
        end

        # Change the url for LIVE
        dev = 'http://dcdev-solr.tcd.ie:8983/solr/tcd-hyrax/'
        primary01 = 'http://digcoll-solr01.tcd.ie:8983/solr/tcd-hyrax/'
        $solr = RSolr.connect(url: dev) 
        work_response = $solr.get('select', params: { q: "id:#{work_id}" })
        work_data = work_response['response']['docs'][0]        
    
        # Extract relevant data from Solr response
        title = work_data['title_tesim'].present? ? work_data['title_tesim'].first : 'No title available'
        shelf_mark = work_data['identifier_tesim'].present? ? work_data['identifier_tesim'].first : 'No shelf mark available'
        doi = work_data['doi_tesim'].present? ? work_data['doi_tesim'].first : 'No DOI available'
        date_created = work_data['date_created_tesim'].present? ? work_data['date_created_tesim'].first : 'No date created available'        
        # Check if creator is present, is an array, and not empty
        creator = work_data['creator_tesim'].present? && work_data['creator_tesim'].is_a?(Array) && !work_data['creator_tesim'].empty? ? work_data['creator_tesim'] : ['Not specified']        
        # Check if contributor is present, is an array, and not empty
        contributor = work_data['contributor_tesim'].present? && work_data['contributor_tesim'].is_a?(Array) && !work_data['contributor_tesim'].empty? ? work_data['contributor_tesim'] : ['Not specified']
          
        folder_numbers = work_data['folder_number_tesim'].first
        file_set_ids = work_data['file_set_ids_ssim']
        
        if folder_numbers.present? && file_set_ids.present?
          image_names = []
    
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
            
            paths = image_names.map { |image_name| "/digicolapp/datastore/web/#{folder_numbers}/#{folder_type}/#{image_name}" }            

            response.headers['Content-Type'] = 'application/pdf'
            response.headers['Content-Disposition'] = "attachment; filename=\"#{work_id}.pdf\""           

            # Call the method to generate and download the PDF
            generate_and_download_pdf(paths, work_id, title, shelf_mark, doi, creator, contributor, date_created, ocr_checkbox_val)
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
    
        paths.each do |url|
          # Get the image data
          image_data = URI.open(url).read


          if ocr_checkbox_val.to_s == "true"
            Rails.logger.debug "ocr_checkbox_val: #{ocr_checkbox_val}"
            # Perform OCR on the image and get the extracted text
            extracted_text = perform_ocr(image_data)
            Rails.logger.debug "Debug message: #{extracted_text}"
            # Embed the extracted OCR text into the PDF
            pdf.text(extracted_text) if extracted_text.present?
          end

          # Resize and compress the image
          resized_image_data = resize_image(image_data)

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
          pdf_filename = "OCR_enabled_pdf_#{file_set_id}.pdf"
          # Perform OCR on the entire PDF to make it searchable
          final_pdf_path = add_ocr_to_pdf(pdf_path, file_set_id)
          Rails.logger.debug "final_pdf_path: #{final_pdf_path}"
          # Send the existing PDF file to the user
          send_file final_pdf_path, filename: pdf_filename, type: 'application/pdf', disposition: 'inline'
        else
          # Send the existing PDF file to the user
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
    
    
  
    private
  
    def add_title_page(pdf, title, shelf_mark, doi, creator, contributor, date_created, logo_path)

      # Add your logo at the top left corner
      pdf.image logo_path, position: :left, width: 232, height: 62      
      pdf.move_down 22 # Adjust as needed
    
      # Add the title
      pdf.font_size 14
      pdf.text title, style: :bold, encoding: 'UTF-8'
      pdf.move_down 10
    

      pdf.font_size 12
      # Add Shelf Mark/Reference Number
      pdf.text "Shelf Mark/Reference Number", style: :bold, encoding: 'UTF-8'
      pdf.text "#{shelf_mark}", encoding: 'UTF-8'
      pdf.move_down 10
    
      # Add DOI
      pdf.text "DOI", style: :bold, encoding: 'UTF-8'
      pdf.text "#{doi}", encoding: 'UTF-8'
      pdf.move_down 10
    
      # Add Creator(s)
      pdf.text "Creator", style: :bold, encoding: 'UTF-8'
      creator.each { |c| pdf.text "#{c}", encoding: 'UTF-8' }
      pdf.move_down 10
    
      # Add Contributor(s)
      pdf.text "Contributor", style: :bold, encoding: 'UTF-8'
      contributor.each { |c| pdf.text "#{c}", encoding: 'UTF-8' }
      pdf.move_down 10
    
      # Add Date Created
      pdf.text "Date", style: :bold, encoding: 'UTF-8'
      pdf.text "#{date_created}", encoding: 'UTF-8'
      pdf.move_down 10          

      # Add the fixed text at the bottom center
      fixed_text = "Library of Trinity College Dublin, Digital Collections (https://digitalcollections.tcd.ie/)"
      pdf.fill_color "888888" # Gray color
      pdf.text_box(fixed_text,
                  at: [pdf.bounds.left, pdf.bounds.bottom + 15], # Adjust Y value as needed
                  width: pdf.bounds.width,
                  height: 30,
                  size: 8,
                  align: :center,
                  encoding: 'UTF-8')
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

    # OCR enabled PDF
    def perform_ocr(image_data)
      base_tempfile_path = "/digicolapp/datastore/pdf/temp/temp_image_file"
      tempfile_path = "#{base_tempfile_path}.jpg"
    
      # Check if the file already exists
      if File.exist?(tempfile_path)
        # Generate a new unique file name
        counter = 1
        while File.exist?("#{base_tempfile_path}_#{counter}.jpg")
          counter += 1
        end
    
        # Update the tempfile_path with the new name
        tempfile_path = "#{base_tempfile_path}_#{counter}.jpg"
      end
    
      File.open(tempfile_path, 'wb') { |f| f.write(image_data) }
    
      # Perform OCR using Tesseract
      ocr_text = RTesseract.new(tempfile_path).to_s.strip
    
      # Delete the temporary image file
      File.delete(tempfile_path) if File.exist?(tempfile_path)
    
      return ocr_text
    end

    def add_ocr_to_pdf(pdf_path, file_set_id)
      ocr_pdf_path = "/digicolapp/datastore/pdf/#{file_set_id}.pdf"
  
      # Convert PDF to images (one image per page)
      `pdftoppm "#{pdf_path}" "#{ocr_pdf_path}" -png`
  
      # Perform OCR on each image and save the OCR'ed text to a file
      Dir["#{ocr_pdf_path}-*.jpg"].each do |image_path|
        `tesseract "#{image_path}" "#{image_path}_ocr" -l eng pdf`
      end
  
      # Merge the OCR'ed text into a new PDF
      `pdftk "#{ocr_pdf_path}-*.pdf" cat output "#{ocr_pdf_path}"`
  
      # Clean up temporary image files
      Dir["#{ocr_pdf_path}-*.png"].each { |image_path| File.delete(image_path) }
      Dir["#{ocr_pdf_path}-*.pdf"].each { |pdf| File.delete(pdf) }
  
      return ocr_pdf_path
    end

   
  end