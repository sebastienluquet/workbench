require 'ruby2ruby'

module ToFile
  def self.extended(obj)
    if obj.is_a? Module
      obj.instance_variable_set :@public_instance_methods, obj.public_instance_methods(false) if obj.instance_variable_get(:@public_instance_methods).nil?
      obj.instance_variable_set :@singleton_methods, obj.singleton_methods(false) if obj.instance_variable_get(:@singleton_methods).nil?
    end
  end

  include Workbench
  def class_method(meth, s = true)
    proc = method(meth)
    (c = Class.new).class_eval { define_method :proc, proc }
    Ruby2Ruby.translate(c, :proc).gsub('def proc', "def #{s ? "self." : ''}#{meth}")
  end
  def instance_method(meth)
    begin
      Ruby2Ruby.translate(self, meth)
    rescue
      if a = ancestors.detect{|m|(m.instance_methods(false)+m.protected_instance_methods(false)+m.private_instance_methods(false)).include? meth.to_s}
        Ruby2Ruby.translate(a, meth)
      else
        raise
      end
    end
  end
  def to_file
  
    f = ""
    def f.puts args
      self << "#{args}\n"
    end

    f.puts "  include ArBase" if self.ancestors.include? ArBase
    f.puts "  set_table_name '#{self.table_name}'" if respond_to? 'original_table_name' #and table_name != original_table_name
    f.puts "  set_inheritance_column '#{self.inheritance_column}'" if respond_to? 'inheritance_column' and self.singleton_methods(false).include? 'inheritance_column'
    f.puts "  set_primary_key '#{self.primary_key}'" if respond_to? 'primary_key'  if respond_to? 'original_primary_key' #and primary_key != original_primary_key
    
    if respond_to? 'reflect_on_all_associations'
      self.reflect_on_all_associations.sort{ |x,y| [x.macro.to_s, x.name.to_s] <=> [y.macro.to_s, y.name.to_s] }.each do |e|
        options = []
        options << (e.class_name == e.send(:derive_class_name) ? nil : ":class_name => '"+e.class_name+"'")
        options << (e.primary_key_name == e.send(:derive_primary_key_name) ? nil : (e.options[:foreign_key] ? ":foreign_key => :"+e.options[:foreign_key].to_s : nil ))
        options << ( e.options[:conditions] ? ":conditions => \"#{e.options[:conditions]}\"" : nil )
        options << ( e.options[:dependent] ? ":dependent => :#{e.options[:dependent]}" : nil )
        options << ( e.options[:finder_sql] ? "\n    :finder_sql => '#{e.options[:finder_sql]}'" : nil )
        options << ":join_table => '#{e.options[:join_table]}'" if send(:join_table_name, undecorated_table_name(self.to_s), undecorated_table_name(e.class_name)) != e.options[:join_table]
        options << ( e.options[:polymorphic] ? ":polymorphic => true" : nil )
        options << ( e.options[:through] ? ":through => :#{e.options[:through]}" : nil )
        if e.active_record == self
            options = options.compact.join(', ')
            options = ", " + options unless options.blank?
            f.puts "  " + e.macro.to_s + " :" + e.name.to_s + options
          end
        end

      self.reflect_on_all_validations.sort{ |x,y| [x.macro.to_s, x.name.to_s] <=> [y.macro.to_s, y.name.to_s] }.each do |e|
        options = []
        options << ( e.options[:is] ? ":is => #{e.options[:is]}" : nil )
        options << ( e.options[:only_integer] ? ":only_integer => #{e.options[:only_integer]}" : nil )
        options << ( e.options[:message] ? ":message => \"#{e.options[:message]}\"" : nil )
        options << ( e.options[:scope] ? ":scope => :#{e.options[:scope]}" : nil )
        options << ( e.options[:minimum] ? ":minimum => #{e.options[:minimum]}" : nil )
        options << ( e.options[:maximum] ? ":maximum => #{e.options[:maximum]}" : nil )
        options << ( e.options[:with] ? ":with => #{e.options[:with]}" : nil )
        options << ( e.options[:within] ? ":within => #{e.options[:within]}" : nil )
        if e.active_record == self
          options = options.compact.join(', ')
          options = ", " + options unless options.blank?
          f.puts "  " + e.macro.to_s + " :" + e.name.to_s + options
        end
      end
    end
    eval "class #{self.name} #{(self.superclass == Object ? '' : ' < ' + self.superclass.to_s)};#{f};end"

    (singleton_methods(false) - self.name.constantize.singleton_methods(false) ).sort.each do |meth|
      f.puts Ruby2Ruby.new.indent(class_method(meth)) if @singleton_methods.include? meth
    end

    (public_instance_methods(false) - self.name.constantize.public_instance_methods(false)).sort.each do |meth|
      f.puts Ruby2Ruby.new.indent(instance_method(meth)) if @public_instance_methods.include? meth
    end

   #send :remove_const, Temp if const_defined? :Temp
   File.open(to_file_path,'w') do |file|
     file.puts "class " + self.name + (self.superclass == Object ? '' : ' < ' + self.superclass.to_s)
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
