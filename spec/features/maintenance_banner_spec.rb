require 'rails_helper'

RSpec.feature 'Homepage Maintenance Banner' do
  scenario "displays the maintenance downtime notice on the homepage" do
    visit("/")

    expect(page).to have_css('.maintenance-notice-banner')
    expect(page).to have_content('Digital Collections downtime')
    expect(page).to have_content('Tuesday 7th and Wednesday 8th July')
  end
end
