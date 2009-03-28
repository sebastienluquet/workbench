module ArBase
  extend ArCBase
  include ArCBase
  def self.included(mod)
    ActiveRecord::Base.extend ToFile
    mod.extend ArCBase

#    mod.extend ActiveRecord::QueryCache::ClassMethods #ok
#    mod.module_eval do
#      include ActiveRecord::Validations #4
#      #include ActiveRecord::Locking::Optimistic, ActiveRecord::Locking::Pessimistic
#      include ActiveRecord::AttributeMethods #1
#      include ActiveRecord::Dirty #3
#      include ActiveRecord::Callbacks, ActiveRecord::Observing, ActiveRecord::Timestamp #5
#      include ActiveRecord::Associations, ActiveRecord::AssociationPreload, ActiveRecord::NamedScope
#
#    # AutosaveAssociation needs to be included before Transactions, because we want
#    # #save_with_autosave_associations to be wrapped inside a transaction.
#      include ActiveRecord::AutosaveAssociation, ActiveRecord::NestedAttributes #3
#
#      include ActiveRecord::Aggregations, ActiveRecord::Transactions, ActiveRecord::Reflection, ActiveRecord::Batches, ActiveRecord::Calculations, ActiveRecord::Serialization #2
#      self.default_scoping = []
#    end
#    def mod.instance_method_already_implemented?(method_name)
#        method_name = method_name.to_s
#        return true if method_name =~ /^id(=$|\?$|$)/
#        @_defined_class_methods         ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map(&:to_s).to_set
#        @@_defined_activerecord_methods ||= (ActiveRecord::Base.public_instance_methods(false) | ActiveRecord::Base.private_instance_methods(false) | ActiveRecord::Base.protected_instance_methods(false)).map(&:to_s).to_set
#        raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
#        @_defined_class_methods.include?(method_name)
#    false
#    end
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
      begin
        self.class.module_eval(ActiveRecord::Base.instance_method(method))
        return send(method, *args)
      rescue
        if ActiveRecord::Base.respond_to? method
          return ActiveRecord::Base.send(method, *args)
        end
        raise
      end
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

      def id
        attr_name = self.class.primary_key
        column = column_for_attribute(attr_name)

        self.class.send(:define_read_method, :id, attr_name, column)
        # now that the method exists, call it
        self.send attr_name.to_sym

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