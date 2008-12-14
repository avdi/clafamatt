
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

  class MacroModule < Module
    def self.find_or_create_for(klass)
      mod = self.new(klass)
      extend_klass = lambda do
        mod.extend_class!
        mod
      end
      klass_singleton = class << klass; self; end
      klass_singleton.ancestors.find(extend_klass){|a|
        a == mod
      }
    end
    def self.find_all_for(klass)
      klass_singleton = class << klass; self; end
      klass_singleton.ancestors.grep(MacroModule)
    end
    def initialize(decorated_class)
      @decorated_class = decorated_class
    end

    def ==(other)
      self.class == other.class && self.decorated_class == other.decorated_class
    end

    def inspect
      "#<Clafamatt::MacroModule:#{@decorated_class}:(#{self.instance_methods(false).join(", ")})>"
    end

    def copy_ancestor_macro_modules!
      @decorated_class.ancestors.each do |ancestor|
        macro_modules = self.class.find_all_for(ancestor)
        macro_modules.each do |mm|
          @decorated_class.extend(mm)
        end
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
        MacroModule.find_or_create_for(self)
      end

      def next_ancestor_responding_to(method)
        ancestors.slice(1..-1).detect{|a| a.respond_to?(method)}
      end

      def can_pass?(method)
        next_ancestor_responding_to(method)
      end

      def pass(method, *args, &block)
        next_ancestor_responding_to(method).send(method, *args, &block)
      end
    end
  end
end  # module Clafamatt

Clafamatt.require_all_libs_relative_to(__FILE__)

# EOF
