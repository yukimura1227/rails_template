gem 'haml-rails'

gem "therubyracer"
gem "less-rails"
gem "twitter-bootstrap-rails"

gem_group :development, :test do
  gem 'pry-rails'
  gem 'pry-doc'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'awesome_print'
end

gem_group :development do
  gem 'erb2haml'
end

run 'bundle install'

rails_command 'haml:replace_erbs'

rails_command 'generate bootstrap:install'
rails_command 'generate bootstrap:layout application fluid -f'

generate(:scaffold, "blog", "title:string", "content:text")
rails_command "db:migrate"

rails_command 'generate bootstrap:themed blogs -f'


file '.pryrc', <<-CODE
  begin
    require 'awesome_print'
    AwesomePrint.pry!
  rescue LoadError
    puts 'no awesome_print :('
  end
CODE
