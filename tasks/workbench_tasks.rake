namespace :db do
  desc 'Generate workbench file from schema.rb and relation'
  task :workbench => :environment do
    include Workbench
    self.database = ActiveRecord::Base.connection.current_database
    generate_fk
  end
end

namespace :workbench do
  desc 'Generate ecore file from models file'
  task :ecore => :environment do
    extend ToFile
    metamodel
  end
end
