require 'ruby2ruby'
require 'parse_tree_extensions'

module ToFile
  def self.extended(obj)
    if obj.is_a? Module
      obj.instance_variable_set :@public_instance_methods, obj.public_instance_methods(false) if obj.instance_variable_get(:@public_instance_methods).nil?
      obj.instance_variable_set :@singleton_methods, obj.singleton_methods(false) if obj.instance_variable_get(:@singleton_methods).nil?
    end
  end
  def update_methods
    update_instance_methods
    update_singleton_methods
  end

  def update_instance_methods
    instance_variable_set :@public_instance_methods, public_instance_methods(false)
  end

  def update_singleton_methods
    instance_variable_set :@singleton_methods, singleton_methods(false)
  end

#  include Workbench
  def class_method(meth, s = true)
    proc = method(meth)
    (c = Class.new).class_eval { define_method :proc, proc }
    Ruby2Ruby.translate(c, :proc).gsub('def proc', "def #{s ? "self." : ''}#{meth}")
  end
  def instance_meth(meth)
    begin
      t = Ruby2Ruby.translate(self, meth)
      if t['attr_reader ']
        if Ruby2Ruby.translate(self, "#{meth}=")['attr_writer ']
          t.gsub!('reader', 'accessor')
        end
      elsif t['attr_writer ']
        if Ruby2Ruby.translate(self, "#{meth.chop}")['attr_reader ']
          t = nil
        end
      end
      t
    rescue
      if a = ancestors.detect{|m|(m.instance_methods(false)+m.protected_instance_methods(false)+m.private_instance_methods(false)).include? meth.to_s}
        Ruby2Ruby.translate(a, meth)
      else
        raise
      end
    end
  end

  def expend_string_hash args
    args.sub(/^\{/, '').sub(/\}$/, '').gsub('=>', ' => ').gsub('{', '{ ').gsub('}', ' }')
  end
  
  def to_file
  
    f = ""
    filter = ""
    def f.puts args
      self << "#{args}\n"
    end

    def filter.puts args
      self << "#{args}\n"
    end

    f.puts "  include ArBase" if self.ancestors.include? ArBase
    
    if singleton_methods(false).include? 'primary_keys'
      f.puts "  set_primary_keys #{self.primary_keys.map{|k|":#{k}"}.join(', ')}"
    end

    if include? Technoweenie::AttachmentFu::InstanceMethods
      f.puts "  has_attachment #{expend_string_hash(attachment_options.dup.delete_if{|k,v| k == :thumbnail_class or k == :processor }.inspect)}"
    end

    if respond_to? 'reflect_on_association' and reflect_on_association(:accepted_roles)
      unless superclass.respond_to? 'reflect_on_association' and superclass.reflect_on_association(:accepted_roles)
        f.puts "  acts_as_authorizable"
      end
    end

    eval "class #{self.name}Temp #{(self.superclass == Object ? '' : ' < ' + self.superclass.to_s)};#{f};end"
    
    included_modules = self.ancestors
    included_modules.shift
    while (m = included_modules.shift) and !m.is_a?(Class) and m != ArBase do
      if m == ActiveRecord::Acts::Tree::InstanceMethods
        options = []
        e = reflect_on_association(:parent)
        if e
          options << ( e.options[:counter_cache] ? ":counter_cache => :#{e.options[:counter_cache]}" : nil )
        end
        options = options.compact.join(', ')
        f.puts "  acts_as_tree" + options
      elsif m == ActiveRecord::Acts::List::InstanceMethods
        options = []
        if respond_to? 'acts_as_list_options'
          options << ":scope => :#{acts_as_list_options[:acts_as_list][:scope]}" if acts_as_list_options[:acts_as_list] and acts_as_list_options[:acts_as_list][:scope]
        end
        options = options.compact.join(', ')
        f.puts "  acts_as_list " + options
      else
        f.puts "  include #{m}" unless "ToFile::#{self.name}Temp".constantize.ancestors.include? m
      end
    end

    if singleton_methods(false).include? 'original_table_name'
      t = table_name
      if t != original_table_name
        f.puts "  set_table_name '#{t}'"
      end
    end

    f.puts "  set_inheritance_column #{self.inheritance_column.blank? ? 'nil' : "'#{self.inheritance_column}'"}" if respond_to? 'inheritance_column' and self.singleton_methods(false).include? 'inheritance_column'
    f.puts "  set_primary_key '#{self.primary_key}'" if singleton_methods(false).include? 'original_primary_key' #and primary_key != original_primary_key

    eval "class #{self.name}Temp #{(self.superclass == Object ? '' : ' < ' + self.superclass.to_s)};#{f};end"
    
    if respond_to? 'reflect_on_all_associations'
      self.reflect_on_all_associations.sort{ |x,y| [x.macro.to_s, x.name.to_s] <=> [y.macro.to_s, y.name.to_s] }.each do |e|
        options = []
        options << (e.class_name == e.send(:derive_class_name) ? nil : ":class_name => '"+e.class_name+"'")
        options << (e.primary_key_name == e.send(:derive_primary_key_name) ? nil : (e.options[:foreign_key] ? ":foreign_key => :"+e.options[:foreign_key].to_s : nil ))
        options << ( e.options[:as] ? ":as => :#{e.options[:as]}" : nil )
        options << ( e.options[:conditions] ? ":conditions => \"#{e.options[:conditions]}\"" : nil )
        options << ( e.options[:dependent] ? ":dependent => :#{e.options[:dependent]}" : nil )
        options << ( e.options[:finder_sql] ? "\n    :finder_sql => '#{e.options[:finder_sql]}'" : nil )
        options << ":join_table => '#{e.options[:join_table]}'" if e.options[:join_table] and send(:join_table_name, undecorated_table_name(self.to_s), undecorated_table_name(e.class_name)) != e.options[:join_table]
        options << ( e.options[:polymorphic] ? ":polymorphic => true" : nil )
        options << ( e.options[:source] ? ":source => :#{e.options[:source]}" : nil )
        options << ( e.options[:through] ? ":through => :#{e.options[:through]}" : nil )
        if e.active_record == self
          unless (a = "ToFile::#{self.name}Temp".constantize.reflect_on_association(e.name)) and a.options.dup.delete_if{|k,v|k==:class_name} == e.options.dup.delete_if{|k,v|k==:class_name}
            options = options.compact.join(', ')
            options = ", " + options unless options.blank?
            f.puts "  " + e.macro.to_s + " :" + e.name.to_s + options
            if respond_to? 'accepts_nested_attributes_options' and accepts_nested_attributes_options[e.name]
              f.puts "  accepts_nested_attributes_for :#{e.name}"#, #{expend_string_hash(delegate_options[k].inspect)}
            end
          end
          end
        end
    end

    if respond_to? 'reflect_on_all_aggregations'
      self.reflect_on_all_aggregations.sort{ |x,y| [x.macro.to_s, x.name.to_s] <=> [y.macro.to_s, y.name.to_s] }.each do |e|
        options = []
        options << ( e.options[:class_name] ? ":class_name => '#{e.options[:class_name]}'" : nil )
        options << ( e.options[:mapping] ? ":mapping => #{e.options[:mapping].inspect}" : nil )
        if e.active_record == self
        #  unless (a = "ToFile::#{self.name}Temp".constantize.reflect_on_association(e.name)) and a.options.dup.delete_if{|k,v|k==:class_name} == e.options.dup.delete_if{|k,v|k==:class_name}
            options = options.compact.join(', ')
            options = ", " + options unless options.blank?
            f.puts "  " + e.macro.to_s + " :" + e.name.to_s + options
        #  end
        end
      end
    end
    if protected_attributes
      protected_attributes.each{|a|
        f.puts "  attr_protected :#{a}"
      }
    elsif accessible_attributes
      accessible_attributes.each{|a|
        f.puts "  attr_accessible :#{a}"
      }
    end
    if respond_to? 'delegate_options'
      delegate_options.keys.sort{|x,y| x.to_s <=> y.to_s}.each{|k|
        f.puts "  delegate :#{k}, #{expend_string_hash(delegate_options[k].inspect)}"
      }
    end
    if respond_to? 'reflect_on_all_validations'
      self.reflect_on_all_validations.sort{ |x,y| [x.macro.to_s, x.name.to_s] <=> [y.macro.to_s, y.name.to_s] }.each do |e|
        options = []
        options << ( e.options[:is] ? ":is => #{e.options[:is]}" : nil )
        options << ( e.options[:only_integer] ? ":only_integer => #{e.options[:only_integer]}" : nil )
        options << ( e.options[:message] ? ":message => \"#{e.options[:message]}\"" : nil )
        options << ( e.options[:scope] ? ":scope => #{e.options[:scope].inspect}" : nil )
        options << ( e.options[:minimum] ? ":minimum => #{e.options[:minimum]}" : nil )
        options << ( e.options[:maximum] ? ":maximum => #{e.options[:maximum]}" : nil )
        options << ( e.options[:with] ? ":with => #{e.options[:with].inspect}" : nil )
        options << ( e.options[:within] ? ":within => #{e.options[:within]}" : nil )
        if e.active_record == self
          options = options.compact.join(', ')
          options = ", " + options unless options.blank?
          f.puts "  " + e.macro.to_s + " :" + e.name.to_s + options
        end
      end
    end

    if respond_to? 'scopes' and respond_to? 'scopes_options'
      scopes.keys.sort{|x,y| x.to_s <=> y.to_s}.each{|k|
        if k != :scoped and (!superclass.respond_to? 'scopes' or superclass.scopes[k].nil?)
          if scopes_options[k].is_a? Hash
            f.puts "  named_scope :#{k}, #{expend_string_hash(scopes_options[k].inspect)}"
          elsif scopes_options[k].is_a? Proc
            f.puts "  named_scope :#{k}, #{Ruby2Ruby.new.indent(scopes_options[k].to_ruby).sub('proc', 'lambda')}"
          end
        end
      }
      if scopes_options['default_scope']
        f.puts "  default_scope #{expend_string_hash(scopes_options['default_scope'].inspect)}"
      end
    end

    eval "class #{self.name}Temp #{(self.superclass == Object ? '' : ' < ' + self.superclass.to_s)};#{f};end"

    (singleton_methods(false) - "ToFile::#{self.name}Temp".constantize.singleton_methods(false) ).sort.each do |meth|
      if @singleton_methods.include? meth
        t = Ruby2Ruby.new.indent(class_method(meth))
        f.puts t unless t.blank?
      end
    end

    @unmetaprogrammed_methods ||= []
    public_meths = (public_instance_methods(false) - "ToFile::#{self.name}Temp".constantize.public_instance_methods(false) + @unmetaprogrammed_methods).uniq
    public_meths.sort.each do |meth|
      if (['initialize'] + @public_instance_methods).include? meth
        t = Ruby2Ruby.new.indent(instance_meth(meth))
        f.puts t unless t.blank?
      end
    end

    protected_meths = (protected_instance_methods(false) - "ToFile::#{self.name}Temp".constantize.protected_instance_methods(false)).uniq
    f.puts "  protected" unless protected_meths.empty?
    protected_meths.sort.each do |meth|
      #if (@public_instance_methods).include? meth
        t = Ruby2Ruby.new.indent(Ruby2Ruby.new.indent(instance_meth(meth)))
        f.puts t unless t.blank?
      #end
    end
    
    ActiveRecord::Callbacks::CALLBACKS.each do |callback_type|
      a = instance_eval("@#{callback_type}_callbacks")
      if a
        a.each do |callback|
          if callback.method.inspect[to_file_path]
            filter.puts Ruby2Ruby.new.indent(callback.method.to_ruby.sub('proc {', "#{callback.kind} {"))
          elsif public_meths.include? callback.method.to_s
            filter.puts "  #{callback.kind} :#{callback.method}"
          end
        end
      end
    end

   #send :remove_const, Temp if const_defined? :Temp
   File.open(to_file_path,'w') do |file|
     file.puts "class " + self.name + (self.superclass == Object ? '' : ' < ' + self.superclass.to_s)
     file.puts filter unless filter.blank?
     file.puts f unless f.blank?
     file.puts "end"
   end
  end
  def to_file_path
    RAILS_ROOT+'/app/models/'+self.to_s.underscore+'.rb'
  end
  require 'rgen/array_extensions'
  require 'rgen/serializer/xmi20_serializer'
  def metamodel
    database = ActiveRecord::Base.connection.current_database.split('_')
    database.pop unless database.size == 1
    database = database.join('_')
    file = File.open(RAILS_ROOT+"/#{database}_metamodel.rb",'w')
    f = ""
    def f.puts args
      self << "#{args}\n"
    end
    f.puts "require 'rgen/metamodel_builder'"
    f.puts "module #{database.camelize}Metamodel"
    f.puts "  extend RGen::MetamodelBuilder::ModuleExtension"
    classes = active_record_models
    classes.each do |c|
      f.puts "  class " + c.name + ' < ' + (c.superclass == ActiveRecord::Base ? 'RGen::MetamodelBuilder::MMBase' : c.superclass.to_s)
      if c.superclass == ActiveRecord::Base
        c.content_columns.each do |col|
          f.puts "    has_attr '#{col.name}', #{'String'}"
        end
      end
      f.puts "  end"
    end
    classes.each do |c|
      c.reflect_on_all_associations(:has_many).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
        if a.name.to_s != 'thumbnails'
          if c.superclass != ActiveRecord::Base and c.superclass.reflect_on_association(a.name)
          else
            if a.class_name.constantize.reflect_on_association(c.name.underscore.to_sym)
              f.puts "  #{c.name}.one_to_many '#{a.name.to_s}', #{a.class_name}, '#{c.name.underscore}'"
            else
              f.puts "  #{c.name}.has_many '#{a.name.to_s}', #{a.class_name}"
            end
          end
        end
      }
#      c.reflect_on_all_associations(:has_and_belongs_to_many).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
#        if c.superclass != ActiveRecord::Base and c.superclass.reflect_on_association(a.name)
#        else
#          f.puts "  #{c.name}.many_to_many '#{a.name.to_s}', #{a.class_name}, #{c.name.underscore.plurialize}"
#        end
#      }
      c.reflect_on_all_associations(:belongs_to).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
        if c.superclass != ActiveRecord::Base and c.superclass.reflect_on_association(a.name)
        else
          unless a.class_name.constantize.reflect_on_association(c.name.underscore.pluralize.to_sym)
            f.puts "  #{c.name}.has_one '#{a.name.to_s}', #{a.class_name}"
          end
        end
      }
    end
    f.puts "end"
    file.puts f
    file.close
    eval f
    File.open("#{database}_metamodel.ecore","w") do |f|
      ser = RGen::Serializer::XMI20Serializer.new(f)
      ser.serialize("ToFile::#{database.camelize}Metamodel".constantize.ecore)
    end
  end
end
