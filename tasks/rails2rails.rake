namespace :rails2rails do
  desc 'Generate workbench file from schema.rb and relation'
  task :regenerate_models => :environment do
  include Workbench
  def active_record_models
    [ BinomialConnectedComponent ]
  end
  active_record_models.each{|m|
    m.extend ToFile
  }
  active_record_models.each{|m|
    m.to_file if m != User and m != Stage
  }
  end
end