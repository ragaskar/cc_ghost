# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cc_ghost/version'

Gem::Specification.new do |spec|
  spec.name          = "cc_ghost"
  spec.version       = CcGhost::VERSION
  spec.authors       = ["Rajan Agaskar"]
  spec.email         = ["ragaskar@gmail.com"]
  spec.summary       = %q{A ephermal CloudController that haunts your rack.}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  # get an array of submodule dirs by executing 'pwd' inside each submodule
  gem_dir = File.expand_path(File.dirname(__FILE__)) + "/"
  `git submodule --quiet foreach pwd`.split($\).each do |submodule_path|
    Dir.chdir(submodule_path) do
      submodule_relative_path = submodule_path.sub gem_dir, ""
      # issue git ls-files in submodule's directory and
      # prepend the submodule path to create absolute file paths
      `git ls-files`.split($\).each do |filename|
        spec.files << "#{submodule_relative_path}/#{filename}"
      end
    end
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "typhoeus", '~> 0.6.7'
  spec.add_development_dependency 'pry'

  spec.add_runtime_dependency 'fork'
  spec.add_runtime_dependency 'addressable'
  spec.add_runtime_dependency 'bcrypt-ruby'
  spec.add_runtime_dependency 'eventmachine', '~> 1.0.0'
  spec.add_runtime_dependency 'fog'
  spec.add_runtime_dependency 'unf'
  spec.add_runtime_dependency 'rfc822'
  spec.add_runtime_dependency 'sequel', '~> 3.48'
  spec.add_runtime_dependency 'sinatra', '~> 1.4'
  spec.add_runtime_dependency 'sinatra-contrib'
  spec.add_runtime_dependency 'yajl-ruby'
  spec.add_runtime_dependency 'membrane', '~> 1.0'
  spec.add_runtime_dependency 'httpclient'
  spec.add_runtime_dependency 'steno'
  spec.add_runtime_dependency 'cloudfront-signer'
  spec.add_runtime_dependency 'vcap_common', '~> 4.0'
  spec.add_runtime_dependency 'allowy'
  spec.add_runtime_dependency 'loggregator_emitter', '~> 3.0'
  spec.add_runtime_dependency 'talentbox-delayed_job_sequel'
  spec.add_runtime_dependency 'newrelic_rpm'
  spec.add_runtime_dependency 'clockwork'
  spec.add_runtime_dependency 'sqlite3'
  #test
  spec.add_runtime_dependency 'machinist', '~> 1.0.6'
  spec.add_runtime_dependency 'webmock'
  spec.add_runtime_dependency 'rack-test'
  spec.add_runtime_dependency 'fakefs'
end
