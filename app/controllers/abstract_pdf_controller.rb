# app/controllers/abstract_pdf_controller.rb

require 'prawn'

class AbstractPdfController < ApplicationController
  # Download the full (untruncated) abstract as a PDF.
  # The abstract is fetched directly from Fedora, which stores the complete text.
  def download
    work_id = params[:id]

    begin
      work = ActiveFedora::Base.find(work_id)
    rescue ActiveFedora::ObjectNotFoundError
      render plain: 'Record not found', status: :not_found and return
    end

    # Fetch the full abstract from Fedora (untruncated)
    full_abstract = if work.respond_to?(:abstract)
                      Array(work.abstract).join("\n\n")
                    else
                      ''
                    end

    if full_abstract.blank?
      render plain: 'No abstract available for this record', status: :not_found and return
    end

    title = Array(work.title).first || 'Untitled'

    pdf = Prawn::Document.new(page_size: 'A4', margin: [40, 50, 40, 50])

    # Use the same OpenSans font as the existing PDF generation
    pdf.font_families.update("OpenSans" => {
      normal: "app/assets/fonts/OpenSans-Regular.ttf",
      bold: "app/assets/fonts/OpenSans-Bold.ttf",
      italic: "app/assets/fonts/OpenSans-RegularItalic.ttf"
    })
    pdf.font "OpenSans"

    # Add TCD logo if available
    logo_path = Rails.root.join('tcd-logo-2x.png')
    if File.exist?(logo_path)
      pdf.image logo_path.to_s, position: :left, width: 232, height: 62
      pdf.move_down 22
    end

    # Title
    pdf.font_size 14
    pdf.text title, style: :bold
    pdf.move_down 10

    # "Abstract" header
    pdf.font_size 12
    pdf.text "Abstract", style: :bold
    pdf.move_down 8

    # Full abstract text
    pdf.font_size 10
    pdf.text full_abstract, align: :justify

    # Footer
    pdf.move_down 20
    pdf.fill_color "888888"
    fixed_text = "Library of Trinity College Dublin, Digital Collections (https://digitalcollections.tcd.ie/)"
    pdf.text_box(fixed_text,
                 at: [pdf.bounds.left, pdf.bounds.bottom + 15],
                 width: pdf.bounds.width,
                 height: 30,
                 size: 8,
                 align: :center)

    send_data pdf.render,
              filename: "#{work_id}_abstract.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  end
end
