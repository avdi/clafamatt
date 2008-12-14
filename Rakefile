# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  load 'tasks/setup.rb'
end

ensure_in_path 'lib'
require 'clafamatt'

task :default => 'spec:run'

PROJ.name = 'clafamatt'
PROJ.authors = 'Avdi Grimm'
PROJ.email = 'avdi@avdi.org'
PROJ.url = 'http://clafamatt.rubyforge.org'
PROJ.version = Clafamatt::VERSION
PROJ.rubyforge.name = 'clafamatt'
PROJ.readme_file = 'README.rdoc'

# Uncomment to disable warnings
# PROJ.ruby_opts = []

# RSpec
PROJ.spec.opts << '--color'

# RDoc
PROJ.rdoc.include << '\.rdoc$'

# Email Announcement
PROJ.ann.email[:from]     = 'avdi@avdi.org'
PROJ.ann.email[:to]       = 'ruby-talk@ruby-lang.org'
PROJ.ann.email[:server]   = 'smtp.gmail.com'
PROJ.ann.email[:domain]   = 'avdi.org'
PROJ.ann.email[:port]     = 587
PROJ.ann.email[:acct]     = 'avdi.grimm'
PROJ.ann.email[:authtype] = :plain

# Notes
PROJ.notes.extensions << '.rdoc'

# EOF
