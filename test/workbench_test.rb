require File.expand_path(File.join(File.dirname(__FILE__), '../../../../test/test_helper'))

ToFile.module_eval do
  def to_file_path
    RAILS_ROOT+'/vendor/plugins/workbench/app/models/'+self.to_s.underscore+'.rb'
  end
end

class WorkbenchTest < Test::Unit::TestCase
  def setup
    EmptyClass.extend ToFile
    EmptyArBaseClass.extend ToFile
    ActiveRecordBaseClass.extend ToFile
    ActiveRecordBaseClassSetTableName.extend ToFile
    p = Papa.new
    p.save
    Papa.table_name
    puts Papa.singleton_methods(false).include?('original_table_name')
    Entity.extend ToFile
    Entity.table_name
    Entity.to_file
  end
  # Replace this with your real tests.
  def test_file_path_in_order_to_write_model_in_plugin_directory
    assert_equal Rails.root.join('vendor', 'plugins', 'workbench', 'app', 'models', 'empty_class.rb').to_s, EmptyClass.to_file_path
  end

  def test_empty_class
    EmptyClass.to_file
  end

  def test_active_record_base_class
    ActiveRecordBaseClass.to_file
  end

  def test_a_record_base_class
    EmptyArBaseClass.to_file
  end
  
  def test_active_record_base_class_set_table_name
    ActiveRecordBaseClassSetTableName.to_file
  end
end
