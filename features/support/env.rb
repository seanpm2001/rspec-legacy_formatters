# For Aruba on 1.9.2
unless File.respond_to?(:write)
  class File
    def self.write(path, content)
      open(path, 'w') { |f| f << content }
    end
  end
end

require 'aruba/cucumber'

timeouts = { 'java' => 60 }

Before do
  @aruba_timeout_seconds = timeouts.fetch(RUBY_PLATFORM) { 10 }
end

Aruba.configure do |config|
  config.before_cmd do |cmd|
    set_env('JRUBY_OPTS', "-X-C #{ENV['JRUBY_OPTS']}") # disable JIT since these processes are so short lived
  end
end if RUBY_PLATFORM == 'java'
