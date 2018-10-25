gems = {
  'haml-rails': {},
  'therubyracer': {},
  'less-rails': { git: 'https://github.com/MustafaZain/less-rails' }, # avoid duprecation error see https://github.com/metaskills/less-rails/issues/122
  'twitter-bootstrap-rails': {},
  'draper': { version: '>= 3.0.0.pre1' }, # 3.0.0.pre1 is avoid error -> active_model/serializers/xml (LoadError)
  'font-awesome-rails': {},
}.freeze

dev_test_gems = {
  'pry-rails': {},
  'pry-doc': {},
  'pry-byebug': {},
  'better_errors': {},
  'binding_of_caller': {},
  'awesome_print': {},
  'rspec-rails': {},
  'rails-controller-testing': {},
  'factory_bot_rails': {},
  'guard-rspec': {require: false},
}.freeze

dev_gems = {
  'erb2haml': {},
  'hirb': {},         # モデルの出力結果を表形式で表示するGem
  'hirb-unicode': {}, # 日本語などマルチバイト文字の出力時の出力結果のずれに対応
  'pry-coolline': {},
  'rubocop': {require: false},
  'view_source_map': {},
  'bullet': {},
}.freeze

test_gems = {
  'faker': {},
  'capybara': {},
  'poltergeist': {},
  'database_cleaner': {},
  'timecop': {},
  'codecov': {require: false},
}.freeze

def plugin?
  unless @yes_or_no
    @yes_or_no = ask('Is This a Plugin?[y/n]')
  end
  @yes_or_no == 'y'
end

# gemspecにTODOがあると動かないので置換する処理
if plugin?
  @lib_name = self.name
  gsub_file "#{@lib_name}.gemspec", /(homepage\s*=\s*)(.*)/, "\\1'https://example.com'"
  gsub_file "#{@lib_name}.gemspec", 'TODO', 'XXXX'
end

def append_dependencies(gems, for_dev = false)
  gems.each do |gem_name, options|
    version = options[:version]
    options.delete(:version) if version
    unless plugin?
      gem gem_name.to_s, version, options
    else
      next if gem_name == :codecov # TODO: pluginだとloadエラーになるので、要原因調査
      next if gem_name == :'twitter-bootstrap-rails' # NOTE: engineではhamlを使えないため
      inject_into_file "#{@lib_name}.gemspec", after: "s.add_development_dependency \"sqlite3\"\n" do
      <<~"RUBY"
      \s\ss.add_#{ for_dev ? 'development_' : '' }dependency '#{gem_name}'
      RUBY
      end
    end
  end
end

append_dependencies(gems)

gem_group :development, :test do
  append_dependencies(dev_test_gems, true)
end

gem_group :development do
  append_dependencies(dev_gems, true)
end

gem_group :test do
  append_dependencies(test_gems, true)
end

run 'bundle install'

rails_command "#{plugin? ? 'app:' : ''}haml:replace_erbs"

if plugin?
  insert_into_file "lib/#{@lib_name}/engine.rb", after: /isolate_namespace.*/ do
        # isolate_namespace Hoge

    <<~"RUBY"
    \n
        config.generators do |g|
          g.template_engine :haml
          g.test_framework = 'rspec'
        end
    RUBY

  end
end

rails_command 'generate rspec:install'
append_to_file '.rspec', <<-CODE
  --format documentation
CODE

inside '' do
  # run 'rm -rf test'
  run 'bundle binstubs rspec-core'
  run 'mkdir spec/features'
  run 'touch spec/features/timecop_sample_spec.rb'
  run 'touch spec/features/blogs_spec.rb'
  run 'touch .pryrc'
end

run 'bundle exec guard init rspec'

# NOTE: twitter-bootstrapのgeneratorが、engineだとerbを生成してしまうので、このgemは使わない
# (gem側では、::Rails.application.config.generators.options[:rails][:template_engine]を見ているため)
unless plugin?
  rails_command 'generate bootstrap:install'
  rails_command 'generate bootstrap:layout application fluid -f'
end

# XXX: avoid reference error cause generated layout refs files below
inside '' do
  run 'touch app/assets/images/apple-touch-icon-144x144-precomposed.png'
  run 'touch app/assets/images/apple-touch-icon-114x114-precomposed.png'
  run 'touch app/assets/images/apple-touch-icon-72x72-precomposed.png'
  run 'touch app/assets/images/apple-touch-icon-precomposed.png'
  run 'touch app/assets/images/favicon.ico'
end

# set confing/application.rb
generators_setting =
  %(# generators settings
    config.generators do |g|
      g.test_framework :rspec,
      fixtures: true,
      view_specs: false,
      helper_specs: false,
      routing_specs: false,
      controller_specs: true,
      request_specs: false
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
    end)
bullet_settings =
  %(  # bullet settings
    config.after_initialize do
      Bullet.enable = true
      Bullet.bullet_logger = false
      Bullet.console = false
      Bullet.add_footer = false
      Bullet.rails_logger = true
    end)

unless plugin?
  application do
    generators_setting
  end

  application(nil, env: 'development') do
    bullet_settings
  end
end

generate(:scaffold, 'blog', 'title:string', 'content:text')
generate(:scaffold, 'comment', 'content:text', 'blog:references')
rails_command 'db:migrate'

# NOTE: twitter-bootstrapのgeneratorが、engineだとerbを生成してしまうので、このgemは使わない
# (gem側では、::Rails.application.config.generators.options[:rails][:template_engine]を見ているため)
unless plugin?
  rails_command "generate bootstrap:themed #{ plugin? ? @lib_name + '/'  : '' }blogs -f"
end

gsub_file "Gemfile", "'sqlite3' groups: %w(test development), require: false\ngem 'pg', groups: %w(production), require: false"
gsub_file 'spec/rails_helper.rb', 'config.use_transactional_fixtures = true', 'config.use_transactional_fixtures = false'
insert_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  %(  # setting for database_cleaner
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
  <<-SETTING_FOR_POLTERGEIST
  Capybara.javascript_driver = :poltergeist
  Capybara.register_driver :poltergeist do |app|
    Capybara::Poltergeist::Driver.new(app, :js_errors => false, :timeout => 60)
  end
  SETTING_FOR_POLTERGEIST
end

insert_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  "  config.include FactoryBot::Syntax::Methods\n"
end

# TODO: pluginだとsimplecovがloadエラーになるので、要原因調査
unless plugin?
  insert_into_file 'spec/spec_helper.rb', before: "RSpec.configure do |config|\n" do
    <<-SETTING_FOR_CODECOV
    require 'simplecov'
    SimpleCov.start

    if ENV['CI'] == 'true'
      require 'codecov'
      SimpleCov.formatter = SimpleCov::Formatter::Codecov
    end
    SETTING_FOR_CODECOV
  end
end

append_to_file "app/assets/stylesheets/#{plugin? ? @lib_name + '/' : '' }application.css", <<-SETTING_FONT_AWESOME_RAILS
/*
 *= require font-awesome
 */
SETTING_FONT_AWESOME_RAILS

append_to_file "app/views/#{plugin? ? @lib_name + '/' : '' }blogs/index.html.haml", <<-USING_FONT_AWESOME_SAMPLE_CODE
= fa_icon 'twitter'
USING_FONT_AWESOME_SAMPLE_CODE

append_to_file 'spec/rails_helper.rb', <<-SPEC_UTILITY
# save screenshot
def take_screenshot
  page.save_screenshot "tmp/capybara/screenshot-\#{DateTime.now}.png"
end
SPEC_UTILITY

append_to_file 'spec/features/timecop_sample_spec.rb', <<-TIMECOP_SAMPLE_SPEC
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

append_to_file 'spec/features/blogs_spec.rb', <<-SAMPLE_FEATURE_SPEC
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

append_to_file '.pryrc', <<-FOR_AWESOMEPRINT
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

# TODO: mailcatcher
