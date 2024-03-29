# Generated via
#  `rails generate hyrax:work Folio`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a Folio', js: true do
  context 'a logged in user' do
    Capybara.javascript_driver = :selenium_chrome_headless
    let(:user_attributes) do
      { email: 'test@example.com' }
    end
    let(:user) do
      User.new(user_attributes) { |u| u.save(validate: false) }
    end

    let(:admin_set_id) { AdminSet.find_or_create_default_admin_set_id }
    let(:permission_template) { Hyrax::PermissionTemplate.find_or_create_by!(source_id: admin_set_id) }
    let(:workflow) { Sipity::Workflow.create!(active: true, name: 'test-workflow', permission_template: permission_template) }

    before do
      # Create a single action that can be taken
      Sipity::WorkflowAction.create!(name: 'submit', workflow: workflow)

      # Grant the user access to deposit into the admin set.
      Hyrax::PermissionTemplateAccess.create!(
        permission_template_id: permission_template.id,
        agent_type: 'user',
        agent_id: user.user_key,
        access: 'deposit'
      )
      login_as user
      #Capybara.page.current_window.resize_to(5000, 5000)
    end

    scenario do
      visit '/dashboard'
      click_link "Works"
      click_link "Add new work"

      # JL: Try to fix random rspec spec failures
      sleep 3

      # If you generate more than one work uncomment these lines
      choose "payload_concern", option: "Folio"
      click_button "Create work"

      # JL: Try to fix random rspec spec failures
      sleep 3

      expect(page).to have_content "Add New Folio"
      click_link "Files" # switch tab
      expect(page).to have_content "Add files"
      expect(page).to have_content "Add folder"
      within('span#addfiles') do
        # byebug
        attach_file("files[]", "#{::Rails.root}/spec/fixtures/image.jpg", visible: false)
        #attach_file("files[]", "#{::Rails.root}/spec/fixtures/jpg_fits.xml", visible: false)
      end
      click_link "Descriptions" # switch tab
      fill_in('Title', with: 'My Test Folio')
      fill_in('Creator', with: 'Doe, Jane')
      fill_in('Keyword', with: 'testing')
      select('Copyright The Board of Trinity College Dublin', from: 'Rights statement')

      # 13-12-2018 JL:    #!#
      click_link("Additional fields")
      fill_in "Format", with: "A Work Genre"
      fill_in "Bibliography", with: "A Work Bibliography"
      fill_in "Page no", with: "A Dris Page No"
      fill_in "Dris document no", with: "A Dris Document Number"
      fill_in "Dris unique", with: "A Dris Unique"
      fill_in "Format duration", with: "A Format Duration"

      fill_in "Copyright status", with: "A Copyright Holder"
      fill_in "Copyright note", with: "A Copyright Note"
      fill_in "Digital root number", with: "A Digital Root Number"
      fill_in "Digital object identifier", with: "A Digital Object Identifier"
      #fill_in "Language code", with: "A Language Code"
      fill_in "Location type", with: "A Location Type"
      #fill_in "Shelf locator", with: "A Shelf Locator"
      #fill_in "Role", with: "A Role"
      #fill_in "Role code", with: "A Role Code"
      fill_in "Sponsor", with: "A Sponsor"
      fill_in "Conservation history", with: "A Conservation History"
      fill_in "Publisher location", with: "A Publisher Location"
      fill_in "Page number", with: "A Page Number"
      fill_in "Page type", with: "A Page Type"
      fill_in "Physical extent", with: "A Physical Extent"
      fill_in "Support", with: "A Support"
      fill_in "Medium", with: "A Medium"
      #fill_in "Type of work", with: "A Type Of Work"
      #fill_in "Subject lcsh", with: "A Subject LCSH"
      #fill_in "Subject local", with: "A Subject Local"
      #fill_in "Subject name", with: "A Subject Name"
      fill_in "Alternative title", with: "An Alternative Title"
      fill_in "Series title", with: "A Series Title"
      fill_in "Collection title", with: "A Collection Title"

      fill_in "Provenance", with: "A Provenance"

      fill_in "Culture", with: "A Culture"
      fill_in "County", with: "A County"
      fill_in "Folder number", with: "A Folder Number"
      fill_in "Project number", with: "A Project Number"
      fill_in "Order no", with: "An Order No"
      fill_in "Total records", with: "A Total Records"
      fill_in "Location", with: "A Location"
      fill_in "Sub Fonds", with: "A Sub Fond"


      # With selenium and the chrome driver, focus remains on the
      # select box. Click outside the box so the next line can't find
      # its element
      find('body').click
      choose('folio_visibility_open')
      expect(page).to have_content('Please note, making something visible to the world (i.e. marking this as Public) may be viewed as publishing which could impact your ability to')
      #byebug

      check('agreement')

      click_on('Save')
      expect(page).to have_content('My Test Folio')
      expect(page).to have_content "Your files are being processed by Digital Collections in the background."
    end
  end
end
