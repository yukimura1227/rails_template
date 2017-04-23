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
  gem 'hirb'         # モデルの出力結果を表形式で表示するGem
  gem 'hirb-unicode' # 日本語などマルチバイト文字の出力時の出力結果のずれに対応
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

  # setup for hirb
  begin
    require "hirb"
  rescue LoadError
    puts "no hirb :("
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
CODE
