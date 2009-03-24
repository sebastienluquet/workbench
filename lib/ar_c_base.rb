module ArCBase
  def self.const_missing(name)
    return ActiveRecord::Base if (name == :Base)
    super
  end

  def class_of_active_record_descendant(klass)
    if ((klass.superclass == Base) or ((klass.superclass == Object) or klass.superclass.abstract_class?)) then
      klass
    else
      if klass.superclass.nil? then
        raise(ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord")
      else
        class_of_active_record_descendant(klass.superclass)
      end
    end
  end

  def descends_from_active_record?
    if ((not (superclass == Object)) and superclass.abstract_class?) then
      superclass.descends_from_active_record?
    else
      ((superclass == Base) or (not columns_hash.include?(inheritance_column)))
    end
  end
  
  def method_missing(method, *args)
    if ActiveRecord::Base.respond_to?(method, true) then
      ArCBase.module_eval(ActiveRecord::Base.class_method(method, false))
      return send(method, *args)
    end
    super
  end

  def undecorated_table_name(class_name = base_class.name)
    table_name = class_name.to_s.demodulize.underscore
    table_name = table_name.pluralize if pluralize_table_names
    table_name
  end

  def define_attr_method(name, value = nil, &block)
    sing = class << self
      self
    end
    unless respond_to? name
      ArCBase.module_eval(ActiveRecord::Base.class_method(name, false))
    end
    sing.send(:alias_method, "original_#{name}", name)
    if block_given? then
      sing.send(:define_method, name, &block)
    else
      sing.class_eval("def #{name}; #{value.to_s.inspect}; end")
    end
  end

  ActiveRecord::Base.class_variables.each do |cv|
    cv = cv.gsub('@@', '')
    module_eval <<-EOF
      def #{cv}
        ActiveRecord::Base.#{cv}
      end
    EOF
  end

  def retrieve_connection
    ActiveRecord::Base.retrieve_connection
        end

  def scoped_methods #:nodoc:
    ActiveRecord::Base.scoped_methods
  end

  def instance_method_already_implemented?(method_name)
#    method_name = method_name.to_s
#    return true if method_name =~ /^id(=$|\?$|$)/
#    @_defined_class_methods         ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map(&:to_s).to_set
#    @@_defined_activerecord_methods ||= (ActiveRecord::Base.public_instance_methods(false) | ActiveRecord::Base.private_instance_methods(false) | ActiveRecord::Base.protected_instance_methods(false)).map(&:to_s).to_set
#    raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
#    @_defined_class_methods.include?(method_name)
    false
  end
  
  def default_scoping=(obj)
    write_inheritable_attribute(:default_scoping, obj)
  end

  def update_counters(id, counters)
    updates = counters.inject([]) { |list, (counter_name, increment)|
      sign = increment < 0 ? "-" : "+"
      list << "#{connection.quote_column_name(counter_name)} = COALESCE(#{connection.quote_column_name(counter_name)}, 0) #{sign} #{increment.abs}"
    }.join(", ")

    if id.is_a?(Array)
      ids_list = id.map {|i| quote_value(i)}.join(', ')
      condition = "IN  (#{ids_list})"
    else
      condition = "= #{quote_value(id)}"
    end

    update_all(updates, "#{connection.quote_column_name(primary_key)} #{condition}")
  end
end