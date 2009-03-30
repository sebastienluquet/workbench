require File.expand_path(File.join(File.dirname(__FILE__), '../../../../test/test_helper'))

ToFile.module_eval do
  def to_file_path
    RAILS_ROOT+'/vendor/plugins/workbench/app/models/'+self.to_s.underscore+'.rb'
  end
end

class WorkbenchTest < Test::Unit::TestCase
  def setup
    EmptyClass.extend ToFile
    p = Papa.new
    p.save
    Papa.table_name
    puts Papa.singleton_methods(false).include?('original_table_name')
  end
  # Replace this with your real tests.
  def test_file_path_in_order_to_write_model_in_plugin_directory
    assert_equal Rails.root.join('vendor', 'plugins', 'workbench', 'app', 'models', 'empty_class.rb').to_s, EmptyClass.to_file_path
  end

  def test_empty_class
    EmptyClass.to_file
  end

  def test_active_record_base_class
    ActiveRecordBaseClass.extend ToFile
    ActiveRecordBaseClass.to_file
  end

  def test_a_record_base_class
    EmptyArBaseClass.to_file
  end

  def test_active_record_base_class_set_table_name
    ActiveRecordBaseClassSetTableName.extend ToFile
    ActiveRecordBaseClassSetTableName.to_file
  end

  def test_empty_ar_base_class_with_set_table_name
    EmptyArBaseClassWithSetTableName.to_file
  end

  def test_ar_base_with_instance_method_class
    ArBaseWithInstanceMethodClass.update_instance_methods
    ArBaseWithInstanceMethodClass.to_file
  end

  def test_ar_base_with_class_method_class
    ArBaseWithClassMethodClass.update_singleton_methods
    ArBaseWithClassMethodClass.to_file
  end

  def test_ar_base_with_include_class
    ArBaseWithIncludeClass.to_file
  end

  def test_active_record_with_include
    ActiveRecordWithIncludeClass.to_file
  end
end
