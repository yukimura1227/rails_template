gem 'haml-rails'

gem 'therubyracer'
gem 'less-rails', git: 'https://github.com/MustafaZain/less-rails' # avoid duprecation error see https://github.com/metaskills/less-rails/issues/122
gem 'twitter-bootstrap-rails'

gem 'draper', '>= 3.0.0.pre1' # 3.0.0.pre1 is avoid error -> active_model/serializers/xml (LoadError)

gem_group :development, :test do
  gem 'pry-rails'
  gem 'pry-doc'
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
  %(
    config.generators do |g|
      g.test_framework :rspec,
      fixtures: true,
      view_specs: false,
      helper_specs: false,
      routing_specs: false,
      controller_specs: true,
      request_specs: false
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end
  )
end

application(nil, env: 'development') do
  %(
    # bullet settings
    config.after_initialize do
      Bullet.enable = true
      Bullet.bullet_logger = false
      Bullet.console = false
      Bullet.add_footer = false
      Bullet.rails_logger = true
    end
  )
end

generate(:scaffold, 'blog', 'title:string', 'content:text')
rails_command 'db:migrate'

rails_command 'generate bootstrap:themed blogs -f'

insert_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  "  config.include FactoryGirl::Syntax::Methods\n"
end

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

# TODO: capybara, poltergyst, Guard, timecop, mailcatcher
