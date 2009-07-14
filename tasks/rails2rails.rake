#require 'vendor/plugins/workbench/lib/to_file'
namespace :rails2rails do
  desc 'Generate workbench file from schema.rb and relation'
  task :regenerate_models do
    ActiveRecord::Base.module_eval do
      extend ToFile
      def self.accepts_nested_attributes_options
        read_inheritable_attribute(:accepts_nested_attributes_options) || write_inheritable_attribute(:accepts_nested_attributes_options, {})
      end
      def self.scopes_options
        read_inheritable_attribute(:scopes_options) || write_inheritable_attribute(:scopes_options, {})
      end
      def self.delegate_options
        read_inheritable_attribute(:delegates_options) || write_inheritable_attribute(:delegates_options, {})
      end
      def self.acts_as_list_options
        read_inheritable_attribute(:acts_as_list_options) || write_inheritable_attribute(:acts_as_list_options, {})
      end
      def self.acts_as_list(options = {})
        acts_as_list_options[:acts_as_list] = options
        configuration = { :column => "position", :scope => "1 = 1" }
        configuration.update(options) if options.is_a?(Hash)

        configuration[:scope] = "#{configuration[:scope]}_id".intern if configuration[:scope].is_a?(Symbol) && configuration[:scope].to_s !~ /_id$/

        if configuration[:scope].is_a?(Symbol)
          scope_condition_method = %(
            def scope_condition
              if #{configuration[:scope].to_s}.nil?
                "#{configuration[:scope].to_s} IS NULL"
              else
                "#{configuration[:scope].to_s} = \#{#{configuration[:scope].to_s}}"
              end
            end
          )
        else
          scope_condition_method = "def scope_condition() \"#{configuration[:scope]}\" end"
        end

        class_eval <<-EOV
          include ActiveRecord::Acts::List::InstanceMethods

          def acts_as_list_class
            ::#{self.name}
          end

          def position_column
            '#{configuration[:column]}'
          end

          #{scope_condition_method}

          before_destroy :remove_from_list
          before_create  :add_to_list_bottom
        EOV
      end
      def self.accepts_nested_attributes_for(*attr_names)
        options = { :allow_destroy => false }
        options.update(attr_names.extract_options!)
        options.assert_valid_keys(:allow_destroy, :reject_if)

        attr_names.each do |association_name|
          if reflection = reflect_on_association(association_name)
            accepts_nested_attributes_options[association_name] = options
            type = case reflection.macro
            when :has_one, :belongs_to
              :one_to_one
            when :has_many, :has_and_belongs_to_many
              :collection
            end

            reflection.options[:autosave] = true
            self.reject_new_nested_attributes_procs[association_name.to_sym] = options[:reject_if]

            # def pirate_attributes=(attributes)
            #   assign_nested_attributes_for_one_to_one_association(:pirate, attributes, false)
            # end
            class_eval %{
              def #{association_name}_attributes=(attributes)
                assign_nested_attributes_for_#{type}_association(:#{association_name}, attributes, #{options[:allow_destroy]})
              end
            }, __FILE__, __LINE__
          else
            raise ArgumentError, "No association found for name `#{association_name}'. Has it been defined yet?"
          end
        end
      end
      def self.named_scope(name, options = {}, &block)
        name = name.to_sym
        scopes_options[name] = options
        scopes[name] = lambda do |parent_scope, *args|
          ActiveRecord::NamedScope::Scope.new(parent_scope, case options
            when Hash
              options
            when Proc
              case parent_scope
              when ActiveRecord::NamedScope::Scope
                with_scope(:find => parent_scope.proxy_options) { options.call(*args) }
              else
                options.call(*args)
              end
          end, &block)
        end
        (class << self; self end).instance_eval do
          define_method name do |*args|
            scopes[name].call(self, *args)
          end
        end
      end
      def self.default_scope(options = {})
        scopes_options['default_scope'] = options
        self.default_scoping << { :find => options, :create => (options.is_a?(Hash) && options.has_key?(:conditions)) ? options[:conditions] : {} }
      end
      def self.delegate(*methods)
        options = methods.pop
        unless options.is_a?(Hash) && to = options[:to]
          raise ArgumentError, "Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, :to => :greeter)."
        end

        if options[:prefix] == true && options[:to].to_s =~ /^[^a-z_]/
          raise ArgumentError, "Can only automatically set the delegation prefix when delegating to a method."
        end

        prefix = options[:prefix] && "#{options[:prefix] == true ? to : options[:prefix]}_"

        allow_nil = options[:allow_nil] && "#{to} && "

        methods.each do |method|
          delegate_options[method] = options
          module_eval(<<-EOS, "(__DELEGATION__)", 1)
            def #{prefix}#{method}(*args, &block)                           # def customer_name(*args, &block)
              #{allow_nil}#{to}.__send__(#{method.inspect}, *args, &block)  #   client && client.__send__(:name, *args, &block)
            end                                                             # end
          EOS
        end
      end
      def self.method_added(name)
        @unmetaprogrammed_methods ||= []
        if respond_to? 'to_file_path' and caller.first[to_file_path]
          @unmetaprogrammed_methods << name.to_s
        end
        super
      end
    end
    Rake::Task['environment'].invoke
    include Workbench
    def active_record_models
      [
        AcceptedRole,
        Activity,
        Apcm,
        Asso,
        Association,
        AuthorizedGroup,
        Binome,
        Binomial,
        BinomialConnectedComponent,
        Choice,
        Component,
        Conference,
        ConnectedComponent,
        ConnectedComponentsGraph,
        ConnectedComponentsUser,
        Continent,
        Country,
        CtiSurvey,
        Department,
        DirectedConnectedComponent,
        EasyMatin,
        Editor,
        Entreprise,
        Etudiant,
        Event,
        EventsOption,
        Exterior,
        Filiere,
        Gala,
        GenealogicalConnectedComponent,
        Godfather,
        Godson,
        Graph,
        Group,
        Groupe,
        In,
        InAndOut,
        Inscription,
        Ipn,
        Job,
        JobCategory,
        JobSector,
        LastQuestion,
        Link,
        Maquette,
        Marker,
        MarkerContinent,
        MarkerCountry,
        MarkerDepartment,
        MarkerEntreprise,
        MarkerRegion,
        MarkerTag,
        Matiere,
        Meeting,
        Membership,
        ModuleIsima,
        Msg,
        Note,
        Out,
        Page,
        Participant,
        ParticipantOption,
        PartnerCompany,
        PartnerSenior,
        PhpbbUser,
        Poste,
        Ppn,
        Projet,
        Promotion,
        Rdd,
        Region,
        Resultat,
        Role,
        ScholarYear,
        Shortpath,
        Stage,
        Subject,
        Subscription,
        Teacher,
        UnDirectedConnectedComponent,
        User,
        Wei,
        Wish,
        YbConfig,
        YbMaquette,
        Yearbook,
        YearbookConfiguration,
        Zz2,
        Zz3
      ]
    end
    def active_record_models
      [
        User
      ]
    end
    active_record_models.each{|m|
      m.extend ToFile
    }
    active_record_models.each{|m|
      m.to_file
    }
  end
end
