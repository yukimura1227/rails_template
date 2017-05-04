gem 'haml-rails'

gem 'therubyracer'
gem 'less-rails', git: 'https://github.com/MustafaZain/less-rails' # avoid duprecation error see https://github.com/metaskills/less-rails/issues/122
gem 'twitter-bootstrap-rails'

gem 'draper', '>= 3.0.0.pre1' # 3.0.0.pre1 is avoid error -> active_model/serializers/xml (LoadError)
gem 'font-awesome-rails'

gem_group :development, :test do
  gem 'pry-rails'
  gem 'pry-doc'
  gem 'pry-byebug'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'awesome_print'
  gem 'rspec-rails'
  gem 'rails-controller-testing'
  gem 'factory_girl_rails'
end

gem_group :development do
  gem 'erb2haml'
  gem 'hirb'         # モデルの出力結果を表形式で表示するGem
  gem 'hirb-unicode' # 日本語などマルチバイト文字の出力時の出力結果のずれに対応
  gem 'pry-coolline'
  gem 'rubocop', require: false
  gem 'view_source_map'
  gem 'bullet'
end

gem_group :test do
  gem 'faker'
  gem 'capybara'
  gem 'poltergeist'
  gem 'database_cleaner'
  gem 'timecop'
end

run 'bundle install'

rails_command 'haml:replace_erbs'

rails_command 'generate rspec:install'
run 'rm -rf test'
run 'bundle binstubs rspec-core'
append_to_file '.rspec', <<-CODE
  --format documentation
CODE

rails_command 'generate bootstrap:install'
rails_command 'generate bootstrap:layout application fluid -f'

# set confing/application.rb
application do
  %(# generators settings
    config.generators do |g|
      g.test_framework :rspec,
      fixtures: true,
      view_specs: false,
      helper_specs: false,
      routing_specs: false,
      controller_specs: true,
      request_specs: false
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end)
end

application(nil, env: 'development') do
  %(  # bullet settings
    config.after_initialize do
      Bullet.enable = true
      Bullet.bullet_logger = false
      Bullet.console = false
      Bullet.add_footer = false
      Bullet.rails_logger = true
    end)
end

generate(:scaffold, 'blog', 'title:string', 'content:text')
generate(:scaffold, 'comment', 'content:text', 'blog:references')
rails_command 'db:migrate'

rails_command 'generate bootstrap:themed blogs -f'

gsub_file 'spec/rails_helper.rb', 'config.use_transactional_fixtures = true', 'config.use_transactional_fixtures = false'
insert_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  %( # setting for database_cleaner
  config.before(:suite) do
    if config.use_transactional_fixtures?
      raise(<<-MSG)
        Delete line `config.use_transactional_fixtures = true` from rails_helper.rb
        (or set it to false) to prevent uncommitted transactions being used in
        JavaScript-dependent specs.

        During testing, the app-under-test that the browser driver connects to
        uses a different database connection to the database connection used by
        the spec. The app's database connection would not be able to access
        uncommitted transaction data setup over the spec's database connection.
      MSG
    end
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, type: :feature) do
    # :rack_test driver's Rack app under test shares database connection
    # with the specs, so continue to use transaction strategy for speed.
    driver_shares_db_connection_with_specs = Capybara.current_driver == :rack_test

    if !driver_shares_db_connection_with_specs
      # Driver is probably for an external browser with an app
      # under test that does *not* share a database connection with the
      # specs, so use truncation strategy.
      DatabaseCleaner.strategy = :truncation
    end
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end
)
end

insert_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do
  "require 'capybara/rspec'\n"
end

insert_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do
  "require 'capybara/poltergeist'\n"
end

insert_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  "  Capybara.javascript_driver = :poltergeist\n"
end

insert_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  "  config.include FactoryGirl::Syntax::Methods\n"
end

append_to_file 'app/assets/stylesheets/application.css', <<-SETTING_FONT_AWESOME_RAILS
/*
 *= require font-awesome
 */
SETTING_FONT_AWESOME_RAILS

append_to_file 'app/views/blogs/index.html.haml', <<-USING_FONT_AWESOME_SAMPLE_CODE
= fa_icon 'twitter'
USING_FONT_AWESOME_SAMPLE_CODE

append_to_file 'spec/rails_helper.rb', <<-SPEC_UTILITY
# save screenshot
def take_screenshot
  page.save_screenshot "tmp/capybara/screenshot-\#{DateTime.now}.png"
end
SPEC_UTILITY

file 'spec/features/timecop_sample_spec.rb', <<-TIMECOP_SAMPLE_SPEC
require 'rails_helper'

feature 'timecop' do
  context 'Timecop#freeze sample' do
    before { Timecop.freeze(Time.now) }
    after { Timecop.return }
    let(:now) { Time.now }
    scenario 'Timecop#freeze stop the Time.now' do
      expect(Time.now).to eq now
    end
  end
  context 'Timecop#travel sample' do
    let(:travel_time) { Time.local(2035, 6, 10, 16, 22, 10) }
    before { Timecop.travel(travel_time) }
    after { Timecop.return }
    scenario 'time cop travel go to the target time' do
      expect(Time.now).to_not eq travel_time
      expect(Time.now > travel_time).to eq true
    end
  end
end
TIMECOP_SAMPLE_SPEC

file 'spec/features/blogs_spec.rb', <<-SAMPLE_FEATURE_SPEC
require 'rails_helper'

feature 'blogs' do
  scenario 'can show blogs', js: true do
    visit blogs_path
    expect(page).to have_content 'Blogs'
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
    expect { click_on 'Create Blog' }.to change(Blog, :count).by(1)
  end
  scenario 'can create blogs twice', js: true do
    visit blogs_path
    click_on 'New'
    fill_in 'Title', with: 'dummy title'
    fill_in 'Content', with: 'dummy content'
    expect { click_on 'Create Blog' }.to change(Blog, :count).by(1)
    visit blogs_path
    click_on 'New'
    fill_in 'Title', with: 'dummy title2'
    fill_in 'Content', with: 'dummy content2'
    expect { click_on 'Create Blog' }.to change(Blog, :count).by(1)
    expect(Blog.count).to eq 2
  end
end
SAMPLE_FEATURE_SPEC

file '.pryrc', <<-FOR_AWESOMEPRINT
# setup for awesomeprint
begin
  require 'awesome_print'
  AwesomePrint.pry!
rescue LoadError
  puts 'no awesome_print :('
end
FOR_AWESOMEPRINT

append_to_file '.pryrc', <<-FOR_HIRB
# setup for hirb
begin
  require 'hirb'
rescue LoadError
  puts 'no hirb :('
end

if defined? Hirb
  # Slightly dirty hack to fully support in-session Hirb.disable/enable toggling
  Hirb::View.instance_eval do
    def enable_output_method
      @output_method = true
      @old_print = Pry.config.print
      Pry.config.print = proc do |*args|
        Hirb::View.view_or_page_output(args[1]) || @old_print.call(*args)
      end
    end

    def disable_output_method
      Pry.config.print = @old_print
      @output_method = nil
    end
  end

  Hirb.enable
end
FOR_HIRB

# TODO: Guard, mailcatcher
