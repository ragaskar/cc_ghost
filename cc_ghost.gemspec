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
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency 'pry'

  spec.add_runtime_dependency 'addressable'
  # spec.add_runtime_dependency 'activesupport', '~> 3.0' # It looks like this is required for DelayedJob, even with the DJ-Sequel extension
  spec.add_runtime_dependency 'rake'
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
  # spec.add_runtime_dependency 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'
  # spec.add_runtime_dependency 'cf-uaa-lib', '~> 1.3.7', git: 'https://github.com/cloudfoundry/cf-uaa-lib.git', ref: '8d34eede'
  # spec.add_runtime_dependency 'cf-message-bus', git: 'https://github.com/cloudfoundry/cf-message-bus.git'
  spec.add_runtime_dependency 'vcap_common', '~> 4.0'
  # spec.add_runtime_dependency 'cf-registrar', git: 'https://github.com/cloudfoundry/cf-registrar.git'
  spec.add_runtime_dependency 'allowy'
  spec.add_runtime_dependency 'loggregator_emitter', '~> 3.0'
  spec.add_runtime_dependency 'talentbox-delayed_job_sequel'
  spec.add_runtime_dependency 'thin', '~> 1.5.1'
  spec.add_runtime_dependency 'newrelic_rpm'
  spec.add_runtime_dependency 'clockwork'
  spec.add_runtime_dependency 'sqlite3'
  #test
  spec.add_runtime_dependency 'rspec-instafail'
  spec.add_runtime_dependency 'rubocop'
  spec.add_runtime_dependency 'debugger'
  spec.add_runtime_dependency 'rspec'
  spec.add_runtime_dependency 'rspec_api_documentation'
  spec.add_runtime_dependency 'machinist', '~> 1.0.6'
  spec.add_runtime_dependency 'webmock'
  spec.add_runtime_dependency 'timecop'
  spec.add_runtime_dependency 'rack-test'
  spec.add_runtime_dependency 'parallel_tests'
  spec.add_runtime_dependency 'fakefs'
end
