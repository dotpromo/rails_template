# Default gems
gem 'pg'
gem 'therubyracer',  platforms: :ruby
gem 'devise', '~> 3.2.4'
gem 'simple_form', '~> 3.1.0.rc1'
gem 'inherited_resources', '~> 1.5.0'
gem 'kaminari', '~> 0.16.1'
gem 'puma', '~> 2.8.2'
gem 'dotenv-deployment', '~> 0.0.2'
gem 'draper', '~> 1.3.0'
sidekiq_installed = false
if yes?('Need background jobs?')
  gem 'sinatra', :require => nil
  gem 'sidekiq', '~> 3.1.4'
  sidekiq_installed = true
  if yes?('Need to limit backgound job queue workers?')
    gem 'sidekiq-limit_fetch', '~> 2.2.4'
  end
end

cancancan_installed = false
if yes?('Need access levels for users?')
  gem 'cancancan', '~> 1.8.2'
  cancancan_installed = true
end

gem_group :development do
  gem 'spring-commands-rspec'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'quiet_assets'
  gem 'rails_layout'
  gem 'capistrano',  '~> 3.1'
  gem 'capistrano-bundler', '>= 1.1.0', require: false
  gem 'capistrano-rvm', require: false
  gem 'capistrano-rails', '~> 1.1', require: false
  gem 'capistrano-runit', require: false, github: 'dotpromo/capistrano-runit'
  gem 'guard', require: false
  gem 'guard-rspec', require: false
  gem 'guard-bundler', require: false
  gem 'terminal-notifier-guard', require: false
  gem 'guard-rubocop', require: false
end

gem_group :development, :test do
  gem 'annotate', '>=2.6.0'
  gem 'ci_reporter', '~> 1.9.0'
  gem 'pry-rails'
  gem 'dotenv-rails'
  gem 'rubocop',  require: false
  gem 'reek',     require: false
  gem 'cane',     require: false
end

gem_group :test do
  gem 'capybara'
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'ffaker'
  gem 'database_cleaner'
  gem 'email_spec'
  if sidekiq_installed
    gem 'rspec-sidekiq', '~> 1.0.0'
    gem 'fakeredis', '~> 0.4.3'
  end
  gem 'simplecov', require: false, github: 'colszowka/simplecov'
  gem 'delorean', '~> 2.1.0'
  gem 'shoulda-matchers', '~> 2.6.1'
  gem 'brakeman', require: false
end

run 'bundle exec guard init'
run "sed -i \"guard :rspec do\" \"guard :rspec, cmd: 'spring rspec -f doc' do\" Guardfile"
run 'rails g cancan:ability' if cancancan_installed
run 'rails g annotate:install'
run 'bundle exec spring binstub rspec'
run 'rails g kaminari:config'
run 'rails g devise:install'
run 'rails g devise:views'
run 'rails g layout:install'
run 'rails g layout:devise'
run 'rails g simple_form:install --bootstrap'
run 'cap install'

file 'Capfile', <<-CODE
require 'capistrano/setup'
require 'capistrano/deploy'
require 'capistrano/rvm'
require 'capistrano/bundler'
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'
require 'capistrano/runit'
require 'capistrano/runit/sidekiq'
require 'capistrano/runit/puma'
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
CODE
file '.gitignore', <<-CODE
/.bundle
/db/*.sqlite3
/db/*.sqlite3-journal
/log/*.log
/tmp
database.yml
doc/
*.swp
*~
.project
.idea
.DS_Store
.coverage
CODE

file '.simplecov', <<-CODE
unless ENV['DISABLE_COVERAGE']
 SimpleCov.merge_timeout 12000
 SimpleCov.start 'rails' do
   add_filter 'app/admin'
   add_group "Decorators", "app/decorators"
 end
end
CODE

file '.rubocop.yml', <<-CODE
AllCops:
  Include:
    - '**/Rakefile'
    - '**/config.ru'
  Exclude:
    - 'db/**/*'
    - 'bin/**/*'
    - 'config/**/*'
    - 'script/**/*'
    - 'spec/**/*'
Documentation:
  Enabled: false
Style/LineLength:
  Max: 99
Style/SignalException:
  EnforcedStyle: only_raise
  SupportedStyles:
    - only_raise
Style/MethodLength:
  Max: 15
CODE

file 'Rakefile', <<-CODE
require File.expand_path('../config/application', __FILE__)

Rails.application.load_tasks

# Code quality metrics
if %w(development test).include? Rails.env
  # rubocop
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new

  task(:default).clear

  # reek
  require 'reek/rake/task'

  Reek::Rake::Task.new do |t|
    t.fail_on_error = false
  end

  # cane
  require 'cane/rake_task'
  Cane::RakeTask.new do |cane|
    cane.abc_max = 15
    cane.no_style = false
    cane.no_doc = true
    cane.style_measure = 99
  end

  # replace default rake task
  task default: [:spec, :rubocop, :reek, :cane]
end
CODE

git :init
git add: '.'
git commit: %Q{ -m 'Initial commit' }
