module Clafamatt

  # :stopdoc:
  VERSION = '1.0.0'
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR

  # Returns the version string for the library.
  #
  def self.version
    VERSION
  end

  # Returns the library path for the module. If any arguments are given,
  # they will be joined to the end of the libray path using
  # <tt>File.join</tt>.
  #
  def self.libpath( *args )
    args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
  end

  # Returns the lpath for the module. If any arguments are given,
  # they will be joined to the end of the path using
  # <tt>File.join</tt>.
  #
  def self.path( *args )
    args.empty? ? PATH : ::File.join(PATH, args.flatten)
  end

  # Utility method used to rquire all files ending in .rb that lie in the
  # directory below this file that has the same name as the filename passed
  # in. Optionally, a specific _directory_ name can be passed in such that
  # the _filename_ does not have to be equivalent to the directory.
  #
  def self.require_all_libs_relative_to( fname, dir = nil )
    dir ||= ::File.basename(fname, '.*')
    search_me = ::File.expand_path(
        ::File.join(::File.dirname(fname), dir, '*', '*.rb'))

    Dir.glob(search_me).sort.each {|rb| require rb}
  end
  # :startdoc:

  # This might be better named SingletonModule.  A MacroModule acts as a
  # container for singleton methods attached to a given class or module.  This
  # way we can share singleton methods across arbitrary classes and modules.
  #
  # MacroModule also ensures that the class being "decorated" with a MacroModule
  # of its own will also inherit all of its ancestors' macros.
  class MacroModule < Module

    # Find or create the macro module for +namespace+ associated with a given
    # class (or module)
    def self.find_or_create_for(klass, namespace = :default)
      mod = self.new(klass, namespace)
      extend_klass = lambda do
        mod.extend_class!
        mod
      end
      klass_singleton = class << klass; self; end
      klass_singleton.ancestors.find(extend_klass){|a|
        a == mod
      }
    end

    # Find all MacroModules associated with a given class or module
    def self.find_all_for(klass, namespace = :default)
      klass_singleton = class << klass; self; end
      klass_singleton.ancestors.grep(MacroModule).select{|a|
        a.namespace == namespace
      }
    end

    # Find all classes and modules in a given class' ancestry which have
    # associated MacroModules for the given namespace
    def self.find_extended(klass, namespace = :default)
      candidates = [klass, *klass.ancestors].uniq
      candidates.select{|c|
        !find_for(c, namespace).nil?
      }
    end

    def self.find_all_for_ancestors(klass, namespace = :default)
      klass.ancestors.map{|c|
        find_for(c, namespace)
      }.compact
    end

    # Given a class or module, find the associated MacroModule, if any. Returns
    # +nil+ if there is no associated MacroModule in the given namespace.
    def self.find_for(klass, namespace = :default)
      klass_singleton = class << klass; self; end
      klass_singleton.ancestors.detect{|a|
        a.is_a?(MacroModule) && a.namespace == namespace
      }
    end

    # Create a new MacroModule for the given namespace, to be associated with
    # the given class. Does not actually attach the module to the class.
    def initialize(decorated_class, namespace = :default)
      @decorated_class = decorated_class
      @namespace       = namespace
    end

    # Equality is defined in terms of being associated with the same class, and
    # being in the same namespace.
    def ==(other)
      self.class == other.class &&
        self.decorated_class == other.decorated_class &&
        self.namespace == other.namespace
    end

    def inspect
      "#<Clafamatt::MacroModule:#{@decorated_class}/#{namespace}:(#{self.instance_methods(false).join(", ")})>"
    end

    # This MacroModule's namespace. A given class can have more than one
    # MacroModule associated with it, for different namespaces.
    def namespace
      @namespace
    end

    def copy_ancestor_macro_modules!
      macro_modules = self.class.find_all_for_ancestors(@decorated_class, namespace)
      macro_modules.reverse.each do |mm|
        @decorated_class.extend(mm)
      end
    end

    def extend_class!
      copy_ancestor_macro_modules!
      @decorated_class.extend(self)
    end
    attr_reader :decorated_class
  end

  module Macros
    def self.append_features(other)
      other.extend(ClassMethods)
      super(other)
    end

    module ClassMethods
      def class_family_reader(*symbols)
        symbols.each do |name|
          ivar   = '@' + name.to_s
          define_macro(name) do ||
              # Explicitly checking for variable definition avoids warnings.
              if instance_variable_defined?(ivar)
                instance_variable_get(ivar)
               # super() doesn't work the way we need in singleton class world
              elsif can_pass?(name)
                pass(name)
              else
                nil
              end
          end
        end
      end

      def class_family_writer(*symbols)
        symbols.each do |name|
          setter = name.to_s + '='
          ivar   = '@' + name.to_s
          define_macro(setter) do |new_value|
            instance_variable_set(ivar, new_value)
          end
        end
      end

      def class_family_accessor(*symbols)
        class_family_reader(*symbols)
        class_family_writer(*symbols)
      end

      def class_family_ancestors(attr_name)
        MacroModule.find_extended(self, :clafamatt)
      end

      # Get all values for the attribute, starting at the nearest class
      def class_family_values(attr_name)
        class_family_ancestors(attr_name).map{|a| a.send(attr_name)}
      end

      # Get the mappings of ancestor class/module to attribute value as a hash
      def class_family_properties(attr_name)
        class_family_ancestors(attr_name).inject({}) {
          |properties, ancestor|
          properties.merge(ancestor => ancestor.send(attr_name))
        }
      end


      private

      def append_features(other)
        other.extend(ClassMethods)
        cmm = clafamatt_macro_module
        other.extend(cmm)
        super(other)
      end

      def define_macro(name, &block)
        cmm = clafamatt_macro_module
        cmm.module_eval do
          define_method(name, &block)
        end
      end

      def clafamatt_macro_module
        MacroModule.find_or_create_for(self, :clafamatt)
      end

      def next_ancestor_responding_to(method)
        ancestor_start_index = singleton? ? 0 : 1
        ancestors.slice(ancestor_start_index..-1).detect{|a|
          a.respond_to?(method)
        }
      end

      def can_pass?(method)
        next_ancestor_responding_to(method)
      end

      def singleton?
        self != self.ancestors.first
      end

      def pass(method, *args, &block)
        next_ancestor_responding_to(method).send(method, *args, &block)
      end
    end
  end
end  # module Clafamatt

Clafamatt.require_all_libs_relative_to(__FILE__)

# EOF
