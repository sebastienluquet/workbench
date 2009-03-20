module TableName
  @@table_name_prefix = ""
  @@pluralize_table_names = true
  @@table_name_suffix = ""
  def base_class
    class_of_active_record_descendant(self)
  end


  def pluralize_table_names
    @@pluralize_table_names
  end
  def reset_table_name
    base = base_class
    name = if (self == base) then
      if ((parent < ActiveRecord::Base) and (not parent.abstract_class?)) then
        contained = parent.table_name
        contained = contained.singularize if parent.pluralize_table_names
        (contained << "_")
      end
      name = "#{table_name_prefix}#{contained}#{undecorated_table_name(base.name)}#{table_name_suffix}"
    else
      base.table_name
    end
    set_table_name(name)
    name
  end
  def set_table_name(value = nil, &block)
    define_attr_method(:table_name, value, &block)
  end
  def table_name
    reset_table_name
  end
  def table_name_prefix
    @@table_name_prefix
  end
  def table_name_suffix
    @@table_name_suffix
  end

  def serialized_class_variables
    class_variables.each { |v|
      e = class_variable_get v.to_sym
      puts("#{v} = #{e == '' ? '""' : e}") }
  end
end
#module ActiveRecord
#  class Base
#    def self.serialized_class_variables
#      class_variables.each { |v| puts("#{v} = #{eval(v) == '' ? '""' : eval(v)}") }
#    end
#  end
#end
class Papa < Object
  extend TableName
end