require 'rails_helper'

feature 'blogs' do
  scenario 'can show blogs', js: true do
    visit blogs_path
    expect(page).to have_content 'blogs'
  end
  scenario 'can using font-awesome-rails', js: true do
    visit blogs_path
    expect(page).to have_css '.fa.fa-twitter'
  end
  scenario 'can create blogs', js: true do
    visit blogs_path
    click_on 'New'
    fill_in 'Title', with: 'dummy title'
    fill_in 'Content', with: 'dummy content'
    expect { click_on 'Save' }.to change(Blog, :count).by(1)
  end
  scenario 'can create blogs twice', js: true do
    visit blogs_path
    click_on 'New'
    fill_in 'Title', with: 'dummy title'
    fill_in 'Content', with: 'dummy content'
    expect { click_on 'Save' }.to change(Blog, :count).by(1)
    visit blogs_path
    click_on 'New'
    fill_in 'Title', with: 'dummy title2'
    fill_in 'Content', with: 'dummy content2'
    expect { click_on 'Save' }.to change(Blog, :count).by(1)
    expect(Blog.count).to eq 2
  end
end
