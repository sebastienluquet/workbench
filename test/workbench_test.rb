require File.expand_path(File.join(File.dirname(__FILE__), '../../../../test/test_helper'))

module ToFile
  def to_file_path
    RAILS_ROOT+'/vendor/plugins/workbench/app/models/'+self.to_s.underscore+'.rb'
  end
end

class WorkbenchTest < Test::Unit::TestCase
  def setup
    EmptyClass.extend ToFile
  end
  # Replace this with your real tests.
  def test_file_path_in_order_to_write_model_in_plugin_directory
    assert_equal Rails.root.join('vendor', 'plugins', 'workbench', 'app', 'models', 'empty_class.rb').to_s, EmptyClass.to_file_path
  end

  def test_empty_class
    EmptyClass.to_file
  end
end
