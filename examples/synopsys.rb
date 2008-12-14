require File.expand_path('../lib/clafamatt', File.dirname(__FILE__))

module Shared
  include Clafamatt::Macros

  class_family_accessor :foo
end

class Parent
  include Shared

end

class Child < Parent
  class_family_accessor :bar
end

Shared.foo                      # =>
Parent.foo                      # =>
Child.foo                       # =>

Shared.foo = "klaatu"
Shared.foo                      # =>
Parent.foo                      # =>
Child.foo                       # =>

Parent.foo = "nikto"
Shared.foo                      # =>
Parent.foo                      # =>
Child.foo                       # =>

Child.foo = "barada"
Parent.foo                      # =>
Child.foo                       # =>

Child.bar = "klaatu"
Child.bar                       # =>
Parent.bar                      # =>
