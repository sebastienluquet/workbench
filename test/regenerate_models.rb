require File.expand_path(File.join(File.dirname(__FILE__), '../../../../test/test_helper'))

#class RegenerateModelsTest < Test::Unit::TestCase
  include Workbench
#  def active_record_models
#    [Activity]
#  end
#  def setup
    active_record_models.each{|m|
      m.extend ToFile
    }
#  end
  # Replace this with your real tests.
#  def test_regenerate_models
    active_record_models.each{|m|
      m.to_file if m != User
    }
#  end
#end
