module ArBase
  def self.included(mod)
    ActiveRecord::Base.extend ToFile
    mod.extend ArCBase

    mod.extend ActiveRecord::QueryCache::ClassMethods #ok
    mod.module_eval do
      include ActiveRecord::Validations #4
      #include ActiveRecord::Locking::Optimistic, ActiveRecord::Locking::Pessimistic
      include ActiveRecord::AttributeMethods #1
      include ActiveRecord::Dirty #3
      include ActiveRecord::Callbacks, ActiveRecord::Observing, ActiveRecord::Timestamp #5
      include ActiveRecord::Associations, ActiveRecord::AssociationPreload, ActiveRecord::NamedScope

    # AutosaveAssociation needs to be included before Transactions, because we want
    # #save_with_autosave_associations to be wrapped inside a transaction.
      include ActiveRecord::AutosaveAssociation, ActiveRecord::NestedAttributes #3

      include ActiveRecord::Aggregations, ActiveRecord::Transactions, ActiveRecord::Reflection, ActiveRecord::Batches, ActiveRecord::Calculations, ActiveRecord::Serialization #2
      self.default_scoping = []
    end
    def mod.instance_method_already_implemented?(method_name)
#        method_name = method_name.to_s
#        return true if method_name =~ /^id(=$|\?$|$)/
#        @_defined_class_methods         ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map(&:to_s).to_set
#        @@_defined_activerecord_methods ||= (ActiveRecord::Base.public_instance_methods(false) | ActiveRecord::Base.private_instance_methods(false) | ActiveRecord::Base.protected_instance_methods(false)).map(&:to_s).to_set
#        raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
#        @_defined_class_methods.include?(method_name)
    false
    end
  end
      def attributes_from_column_definition
        self.class.columns.inject({}) do |attributes, column|
          attributes[column.name] = column.default unless column.name == self.class.primary_key
          attributes
        end
      end
      def initialize(attributes = nil)
        @attributes = attributes_from_column_definition
        @attributes_cache = {}
        @new_record = true
        ensure_proper_type
        self.attributes = attributes unless attributes.nil?
        self.class.send(:scope, :create).each { |att,value| self.send("#{att}=", value) } if self.class.send(:scoped?, :create)
        result = yield self if block_given?
        callback(:after_initialize) if respond_to_without_attributes?(:after_initialize)
        result
      end
  def method_missing method, *args
    if (ActiveRecord::Base.instance_methods + ActiveRecord::Base.protected_instance_methods + ActiveRecord::Base.private_instance_methods).include? method.to_s
      self.class.module_eval(ActiveRecord::Base.instance_method(method))
      return send(method, *args)
    end
    super
  end
      def save
        create_or_update
      end
      def save!
        create_or_update || raise(RecordNotSaved)
      end
      def create_or_update
        raise ReadOnlyRecord if readonly?
        result = new_record? ? create : update
        result != false
  end
     def create_or_update
        raise ReadOnlyRecord if readonly?
        result = new_record? ? create : update
        result != false
      end

      # Updates the associated record with values matching those of the instance attributes.
      # Returns the number of affected rows.
      def update(attribute_names = @attributes.keys)
        quoted_attributes = attributes_with_quotes(false, false, attribute_names)
        return 0 if quoted_attributes.empty?
        connection.update(
          "UPDATE #{self.class.quoted_table_name} " +
          "SET #{quoted_comma_pair_list(connection, quoted_attributes)} " +
          "WHERE #{connection.quote_column_name(self.class.primary_key)} = #{quote_value(id)}",
          "#{self.class.name} Update"
        )
      end

      # Creates a record with values matching those of the instance attributes
      # and returns its id.
      def create
        if self.id.nil? && connection.prefetch_primary_key?(self.class.table_name)
          self.id = connection.next_sequence_value(self.class.sequence_name)
        end

        quoted_attributes = attributes_with_quotes

        statement = if quoted_attributes.empty?
          connection.empty_insert_statement(self.class.table_name)
        else
          "INSERT INTO #{self.class.quoted_table_name} " +
          "(#{quoted_column_names.join(', ')}) " +
          "VALUES(#{quoted_attributes.values.join(', ')})"
        end

        self.id = connection.insert(statement, "#{self.class.name} Create",
          self.class.primary_key, self.id, self.class.sequence_name)

        @new_record = false
        id
      end
      def reload(options = nil)
        clear_aggregation_cache
        clear_association_cache
        @attributes.update(self.class.find(self.id, options).instance_variable_get('@attributes'))
        @attributes_cache = {}
        self
      end
      def destroy(id)
        if id.is_a?(Array)
          id.map { |one_id| destroy(one_id) }
        else
          find(id).destroy
        end
      end
end

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
    if ActiveRecord::Base.respond_to?(method) then
      ArCBase.module_eval(ActiveRecord::Base.class_method(method, false))
      return send(method, *args)
    end
    super
  end
  def table_name_prefix
    ActiveRecord::Base.table_name_prefix
  end
  def pluralize_table_names
    ActiveRecord::Base.pluralize_table_names
  end
  def table_name_suffix
    ActiveRecord::Base.table_name_suffix
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
  def connection
    ActiveRecord::Base.connection
  end
  def default_timezone
    ActiveRecord::Base.default_timezone
  end
  def primary_key_prefix_type
    ActiveRecord::Base.primary_key_prefix_type
  end
  def reset_locking_column
    ActiveRecord::Base.reset_locking_column
  end
  def valid_keys_for_belongs_to_association
    ActiveRecord::Base.valid_keys_for_belongs_to_association
  end
  def valid_keys_for_has_and_belongs_to_many_association
    ActiveRecord::Base.valid_keys_for_has_and_belongs_to_many_association
  end
  def valid_keys_for_has_many_association
    ActiveRecord::Base.valid_keys_for_has_many_association
  end
  def valid_keys_for_has_one_association
    ActiveRecord::Base.valid_keys_for_has_one_association
  end
  def lock_optimistically
    ActiveRecord::Base.lock_optimistically
  end
      def instance_method_already_implemented?(method_name)
#        method_name = method_name.to_s
#        return true if method_name =~ /^id(=$|\?$|$)/
#        @_defined_class_methods         ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map(&:to_s).to_set
#        @@_defined_activerecord_methods ||= (ActiveRecord::Base.public_instance_methods(false) | ActiveRecord::Base.private_instance_methods(false) | ActiveRecord::Base.protected_instance_methods(false)).map(&:to_s).to_set
#        raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
#        @_defined_class_methods.include?(method_name)
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