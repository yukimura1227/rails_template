gem_group :development, :test do
  gem 'pry-rails'
  gem 'pry-doc'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'awesome_print'
end

run 'bundle install'
generate(:scaffold, "blog", "title:string", "content:text")

rails_command "db:migrate"
