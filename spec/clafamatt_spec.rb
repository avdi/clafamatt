require File.join(File.dirname(__FILE__), %w[spec_helper])

describe Clafamatt::MacroModule do
  before :each do
    @class = Clafamatt::MacroModule
  end

  specify { @class.should be_a_kind_of(Module) }

  describe "given a class to decorate" do
    before :each do
      @decorated_class = Class.new
      @decorated_class_singleton = class << @decorated_class; self; end
      @it = @class.find_or_create_for(@decorated_class)
    end

    it "should know its decorated class" do
      @it.decorated_class.should equal(@decorated_class)
    end

    it "should be a singleton ancestor of its decorated class" do
      @decorated_class_singleton.ancestors.should include(@it)
    end

    it "should match another MacroModule decorating the same class" do
      @it.should == @class.new(@decorated_class)
    end

    it "should only decorate a given class once" do
      macro_module = @class.find_or_create_for(@decorated_class)
      macro_module.should equal(@it)
    end
  end

  describe "decorating a child of a decorated class" do
    before :each do
      @parent_class = Class.new
      @child_class  = Class.new(@parent_class)
      @parent_class_singleton = class << @parent_class; self; end
      @child_class_singleton = class << @child_class; self; end
      @parent_macro_module = @class.find_or_create_for(@parent_class)
      @it = @class.find_or_create_for(@child_class)
    end

    it "should decorate the child with a new macro module" do
      @it.should_not equal(@parent_macro_module)
    end

    it "should decorate the child with itself" do
      @child_class_singleton.ancestors.should include(@it)
    end

    it "should decorate the child with the parent macro module" do
      @child_class_singleton.ancestors.should include(@parent_macro_module)
    end
  end

  describe "decorating a module" do
    before :each do
      @decorated_module = Module.new
      @module_singleton = class << @decorated_module; self; end
      @it = @class.find_or_create_for(@decorated_module)
    end

    it "should be one of the module's singleton ancestors" do
      @module_singleton.ancestors.should include(@it)
    end
  end

  describe "decorating a module included in a class" do
    before :each do
      @decorated_module = decorated_module = Module.new
      @module_singleton = class << @decorated_module; self; end
      @it = @class.find_or_create_for(@decorated_module)
      @host_class = Class.new do
        include decorated_module
      end
      @host_class_singleton = class << @host_class; self; end
      @host_class_macro_module = @class.find_or_create_for(@host_class)
    end

    it "should be one of the class's singleton ancestors" do
      @host_class_singleton.ancestors.should include(@it)
    end

    it "should not be the class's own macro module" do
      @host_class_macro_module.should_not equal(@it)
    end
  end

  describe "decorating a child class whose parent includes a decorated module" do
    before :each do
      @decorated_module = decorated_module = Module.new
      @module_singleton = class << @decorated_module; self; end
      @module_macro_module = @class.find_or_create_for(@decorated_module)
      @host_class = Class.new do
        include decorated_module
      end
      @host_class_singleton = class << @host_class; self; end
      @host_class_macro_module = @class.find_or_create_for(@host_class)
      @child_class = Class.new(@host_class)
      @it = @class.find_or_create_for(@child_class)
      @child_class_singleton = class << @child_class; self; end
      @child_class_singleton_ancestors = @child_class_singleton.ancestors
    end

    it "should decorate the child with its own macro module" do
      @it.should_not equal(@module_macro_module)
      @it.should_not equal(@host_class_macro_module)
    end

    it "should decorate the child in the expected order" do
      @child_class_singleton_ancestors.index(@it).should == 0
      @child_class_singleton_ancestors.index(@host_class_macro_module).
        should == 1
      @child_class_singleton_ancestors.index(@module_macro_module).
        should == 2
    end
  end
end

describe "Class Family Attributes:" do
  before :each do
    @shared = shared = Module.new do
      include Clafamatt::Macros
      def self.name; "Shared"; end
      class_family_reader   :mro    # Module Read-Only
      class_family_writer   :mwo    # Module Write-Only
      class_family_accessor :mrw    # Module Read/Write
    end

    @parent = Class.new do
      include shared
      def self.name; "Parent"; end
      class_family_reader   :ro1, :ro2 # Read-Only
      class_family_writer   :wo1, :wo2 # Write-Only
      class_family_accessor :rw1, :rw2 # Read/Write
    end

    @child = Class.new(@parent) do
      def self.name; "Child"; end
      class_family_reader   :cro      # Child Read-Only
      class_family_writer   :cwo      # Child Write-Only
      class_family_accessor :crw      # Child Read/Write
    end
  end

  describe "a module with CFAs" do
    before :each do
    end

    it "should have reader methods for all readable attributes" do
      @shared.methods.should include("mro", "mrw")
    end
    it "should not have reader methods for write-only attributes" do
      @shared.methods.should_not include("mwo")
    end
    it "should have writer methods for writable attributes" do
      @shared.methods.should include("mwo=", "mrw=")
    end
    it "should not have writer methods for read-only attributes" do
      @shared.methods.should_not include("mro=")
    end

    it "should default readable attributes to nil" do
      @shared.mrw.should be_nil
      @shared.mro.should be_nil
    end

    it "should be able to write to writable attributes" do
      @shared.mrw = "klaatu"
      @shared.mrw.should == "klaatu"
      @shared.mwo = "nikto"
      @shared.instance_variable_get(:@mwo).should == "nikto"
    end

    it "should be able to read readable attributes" do
      @shared.instance_variable_set(:@mro, "klaatu")
      @shared.mro.should == "klaatu"
      @shared.instance_variable_set(:@mrw, "nikto")
      @shared.mrw.should == "nikto"
    end

  end
  describe "defined in a class" do
    before :each do
    end

    it "should be able to write to included writable attributes" do
      @parent.mrw = "klaatu"
      @parent.mrw.should == "klaatu"
      @parent.mwo = "nikto"
      @parent.instance_variable_get(:@mwo).should == "nikto"
    end

    it "should not interfere with values in included module" do
      @shared.mrw = "barada"
      @parent.mrw = "klaatu"
      @shared.mrw.should == "barada"
      @parent.mrw.should == "klaatu"
    end

    it "should be able to read included readable attributes" do
      @parent.instance_variable_set(:@mro, "klaatu")
      @parent.mro.should == "klaatu"
      @parent.instance_variable_set(:@mrw, "nikto")
      @parent.mrw.should == "nikto"
    end

    it "should be able to read the class readable attributes" do
      @parent.instance_variable_set(:@ro1, "oompah")
      @parent.instance_variable_set(:@ro2, "loompah")
      @parent.instance_variable_set(:@rw1, "doopidy")
      @parent.instance_variable_set(:@rw2, "doo")
      @parent.ro1.should == "oompah"
      @parent.ro2.should == "loompah"
      @parent.rw1.should == "doopidy"
      @parent.rw2.should == "doo"
    end

    it "should be able to write the class writable attributes" do
      @parent.wo1 = "oompah"
      @parent.wo2 = "loompah"
      @parent.rw1 = "doopidy"
      @parent.rw2 = "doo"
      @parent.instance_variable_get(:@wo1).should == "oompah"
      @parent.instance_variable_get(:@wo2).should == "loompah"
      @parent.instance_variable_get(:@rw1).should == "doopidy"
      @parent.instance_variable_get(:@rw2).should == "doo"
    end
  end
  describe "defined in a child class" do
    it "should be able to read and write module-defined attributes" do
      @child.mrw = "klaatu"
      @child.mrw.should == "klaatu"
      @shared.mrw.should be_nil
    end
    it "should be able to read and write parent-defined attributes" do
      @child.rw1 = "barada"
      @child.rw1.should == "barada"
      @parent.rw1.should be_nil
    end
    it "should be able to read and write child-defined attributes" do
      @child.crw = "nikto"
      @child.crw.should == "nikto"
    end
    it "should not define child attributes on parent or module" do
      lambda do
        @shared.crw = "foo"
      end.should raise_error(NoMethodError)
      lambda do
        @parent.crw = "foo"
      end.should raise_error(NoMethodError)
    end

    it "should inherit values from module-defined attributes" do
      @shared.mrw = "foo"
      @parent.mrw.should == "foo"
      @child.mrw.should == "foo"
    end

    it "should inherit values from parent-defined attributes" do
      @parent.rw1 = "bar"
      @child.rw1.should == "bar"
    end
  end
end

# EOF
