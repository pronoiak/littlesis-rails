feature 'help pages' do
  let(:admin) { create_admin_user }
  let(:index_page) { create(:help_page, name: 'index', title: 'help pages') }
  let(:page_name) { HelpPage.pagify_name(Faker::Book.genre.tr(' ', '_').tr('/', '_')) }
  let(:page_title) { Faker::Book.title }
  let(:help_page) { create(:help_page) }

  scenario 'visting the help pages index' do
    visit "/help"
    expect(page.status_code).to eq 200
    page_has_selector 'h1', text: 'LittleSis Help'
  end

  scenario 'visiting a help page' do
    visit "/help/#{help_page.name}"
    successfully_visits_page "/help/#{help_page.name}"
  end

  context 'with an admin account' do
    let(:help_pages) { create_list(:help_page, 2) }

    before { login_as(admin, scope: :user) }

    after { logout(admin) }

    scenario 'creating a new help page' do
      original_help_page_count = HelpPage.count
      visit "/help/new"
      successfully_visits_page "/help/new"
      page_has_selector 'h1', text: 'Create a new help page'

      fill_in 'help_page_name', :with => page_name
      fill_in 'help_page_title', :with => page_title
      click_button 'submit'

      expect(HelpPage.count).to eql(original_help_page_count + 1)

      last_page = HelpPage.last
      successfully_visits_page "/help/#{last_page.name}/edit"
    end

    scenario 'visiting the list of all pages' do
      help_pages
      visit "/help/pages"
      successfully_visits_page "/help/pages"

      page_has_selector 'th', text: "Name"
      page_has_selector 'th', text: "Edit"
      page_has_selector 'th', text: "Updated at"

      page_has_selector 'tbody tr', count: 2
    end
  end
end
