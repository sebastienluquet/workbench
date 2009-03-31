require File.expand_path(File.join(File.dirname(__FILE__), '../../../../test/test_helper'))

ToFile.module_eval do
  def to_file_path
    RAILS_ROOT+'/vendor/plugins/workbench/app/models/'+self.to_s.underscore+'.rb'
  end
end

class NewTest < Test::Unit::TestCase
  def setup
  end

  def test_active_record_with_habtm_class
    ActiveRecordWithHabtmClass.extend ToFile
    ActiveRecordWithHabtmClass.to_file
  end
end