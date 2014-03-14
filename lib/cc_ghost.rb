require "cc_ghost/version"
# require './vendor/cloud_controller_ng/spec/spec_helper'

$:.unshift(File.expand_path("../../vendor/cloud_controller_ng/lib", __FILE__))
$:.unshift(File.expand_path("../../vendor/cloud_controller_ng/app", __FILE__))
$:.unshift(File.expand_path("../../vendor/cf-message-bus/lib", __FILE__))
$:.unshift(File.expand_path("../../vendor/cf-uaa-lib/lib", __FILE__))
$:.unshift(File.expand_path("../../vendor/cf-registrar/lib", __FILE__))
$:.unshift(File.expand_path("../../vendor/vcap-concurrency/lib", __FILE__))
$:.unshift(File.expand_path("../../vendor/dependency_stubs/", __FILE__))

require "rubygems"
require "bundler"
require "bundler/setup"

require "machinist/sequel"
require "machinist/object"
require "fakefs/safe"
require "rack/test"

require "webmock/rspec"
require "cf_message_bus/mock_message_bus"

require "cloud_controller"
require "allowy/rspec"

require "pry"
require "posix/spawn"

module VCAP::CloudController
  MAX_LOG_FILE_SIZE_IN_BYTES = 100_000_000
  class SpecEnvironment
    def initialize
      ENV["CC_TEST"] = "true"
      reset_database
      VCAP::CloudController::DB.load_models(config.fetch(:db), db_logger)
      VCAP::CloudController::Config.run_initializers(config)

      VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
    end

    def spec_dir
      File.expand_path("..", __FILE__)
    end

    def artifacts_dir
      File.join(spec_dir, "artifacts")
    end

    def artifact_filename(name)
      File.join(artifacts_dir, name)
    end

    def log_filename
      artifact_filename("spec.log")
    end

    def reset_database
      prepare_database

      db.tables.each do |table|
        drop_table_unsafely(table)
      end

      DBMigrator.new(db).apply_migrations
    end

    def reset_database_with_seeds
      reset_database
      VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
    end

    def db_connection_string
      if ENV["DB_CONNECTION"]
        "#{ENV["DB_CONNECTION"]}/cc_test_#{ENV["TEST_ENV_NUMBER"]}"
      else
        "sqlite:///tmp/cc_test#{ENV["TEST_ENV_NUMBER"]}.db"
      end
    end

    def db
      Thread.current[:db] ||= VCAP::CloudController::DB.connect(config.fetch(:db), db_logger)
    end

    def db_logger
      return @db_logger if @db_logger
      @db_logger = Steno.logger("cc.db")
      if ENV["DB_LOG_LEVEL"]
        level = ENV["DB_LOG_LEVEL"].downcase.to_sym
        @db_logger.level = level if Steno::Logger::LEVELS.include? level
      end
      @db_logger
    end

    def config(config_override={})
      config_file = File.expand_path("../../vendor/cloud_controller_ng/config/cloud_controller.yml", __FILE__)
      config_hash = VCAP::CloudController::Config.from_file(config_file)

      config_hash.merge!(
        :nginx => {:use_nginx => true},
        :resource_pool => {
          :resource_directory_key => "spec-cc-resources",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          },
        },
        :packages => {
          :app_package_directory_key => "cc-packages",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          },
        },
        :droplets => {
          :droplet_directory_key => "cc-droplets",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          },
        },

        :db => {
          :log_level => "debug",
          :database => db_connection_string,
          :pool_timeout => 10
        }
      )

      config_hash.merge!(config_override || {})

      res_pool_connection_provider = config_hash[:resource_pool][:fog_connection][:provider].downcase
      packages_connection_provider = config_hash[:packages][:fog_connection][:provider].downcase
      Fog.mock! unless (res_pool_connection_provider == "local" || packages_connection_provider == "local")

      config_hash
    end

    private

    def prepare_database
      if db.database_type == :postgres
        db.execute("CREATE EXTENSION IF NOT EXISTS citext")
      end
    end

    def drop_table_unsafely(table)
      case db.database_type
      when :sqlite
        db.execute("PRAGMA foreign_keys = OFF")
        db.drop_table(table)
        db.execute("PRAGMA foreign_keys = ON")

      when :mysql
        db.execute("SET foreign_key_checks = 0")
        db.drop_table(table)
        db.execute("SET foreign_key_checks = 1")

        # Postgres uses CASCADE directive in DROP TABLE
        # to remove foreign key contstraints.
        # http://www.postgresql.org/docs/9.2/static/sql-droptable.html
      else
        db.drop_table(table, :cascade => true)
      end
    end
  end
end

$spec_env = VCAP::CloudController::SpecEnvironment.new

module VCAP::CloudController::SpecHelper
  def db
    $spec_env.db
  end

  # Note that this method is mixed into each example, and so the instance
  # variable we created here gets cleared automatically after each example
  def config_override(hash)
    @config_override ||= {}
    @config_override.update(hash)

    @config = nil
    config
  end

  def config
    @config ||= begin
      config = $spec_env.config(@config_override)
      configure_components(config)
      config
    end
  end

  def configure
    config
  end

  def configure_components(config)
    # DO NOT override the message bus, use the same mock that's set the first time
    message_bus = VCAP::CloudController::Config.message_bus || CfMessageBus::MockMessageBus.new

    VCAP::CloudController::Config.configure_components(config)
    VCAP::CloudController::Config.configure_components_depending_on_message_bus(message_bus)
    # reset the dependency locator
    CloudController::DependencyLocator.instance.send(:initialize)

    configure_stacks
  end

  def configure_stacks
    stacks_file = File.join(fixture_path, "config/stacks.yml")
    VCAP::CloudController::Stack.configure(stacks_file)
    VCAP::CloudController::Stack.populate
  end

  class TmpdirCleaner
    def self.dir_paths
      @dir_paths ||= []
    end

    def self.clean_later(dir_path)
      dir_path = File.realpath(dir_path)
      tmpdir_path = File.realpath(Dir.tmpdir)

      unless dir_path.start_with?(tmpdir_path)
        raise ArgumentError, "dir '#{dir_path}' is not in #{tmpdir_path}"
      end
      dir_paths << dir_path
    end

    def self.clean
      FileUtils.rm_rf(dir_paths)
      dir_paths.clear
    end

    def self.mkdir
      dir_path = Dir.mktmpdir
      clean_later(dir_path)
      yield(dir_path)
      dir_path
    end
  end

  RSpec.configure do |rspec_config|
    rspec_config.after(:all) do
      TmpdirCleaner.clean
    end
  end

  def create_zip(zip_name, file_count, file_size=1024)
    (file_count * file_size).tap do |total_size|
      files = []
      file_count.times do |i|
        tf = Tempfile.new("ziptest_#{i}")
        files << tf
        tf.write("A" * file_size)
        tf.close
      end

      child = POSIX::Spawn::Child.new("zip", zip_name, *files.map(&:path))
      unless child.status.exitstatus == 0
        raise "Failed zipping:\n#{child.err}\n#{child.out}"
      end
    end
  end

  def create_zip_with_named_files(opts = {})
    file_count = opts[:file_count] || 0
    hidden_file_count = opts[:hidden_file_count] || 0
    file_size = opts[:file_size] || 1024

    result_zip_file = Tempfile.new("tmpzip")

    TmpdirCleaner.mkdir do |tmpdir|
      file_names = file_count.times.map { |i| "ziptest_#{i}" }
      file_names.each { |file_name| create_file(file_name, tmpdir, file_size) }

      hidden_file_names = hidden_file_count.times.map { |i| ".ziptest_#{i}" }
      hidden_file_names.each { |file_name| create_file(file_name, tmpdir, file_size) }

      zip_process = POSIX::Spawn::Child.new(
        "zip", result_zip_file.path, *(file_names | hidden_file_names), :chdir => tmpdir)

      unless zip_process.status.exitstatus == 0
        raise "Failed zipping:\n#{zip_process.err}\n#{zip_process.out}"
      end
    end

    result_zip_file
  end

  def create_file(file_name, dest_dir, file_size)
    File.open(File.join(dest_dir, file_name), "w") do |f|
      f.write("A" * file_size)
    end
  end

  def unzip_zip(file_path)
    TmpdirCleaner.mkdir do |tmpdir|
      child = POSIX::Spawn::Child.new("unzip", "-d", tmpdir, file_path)
      unless child.status.exitstatus == 0
        raise "Failed unzipping:\n#{child.err}\n#{child.out}"
      end
    end
  end

  def list_files(dir_path)
    [].tap do |file_paths|
      Dir.glob("#{dir_path}/**/*", File::FNM_DOTMATCH).each do |file_path|
        next unless File.file?(file_path)
        file_paths << file_path.sub("#{dir_path}/", "")
      end
    end
  end

  def act_as_cf_admin(&block)
    VCAP::CloudController::SecurityContext.stub(:admin? => true)
    block.call
  ensure
    VCAP::CloudController::SecurityContext.unstub(:admin?)
  end

  def with_em_and_thread(opts = {}, &blk)
    auto_stop = opts.has_key?(:auto_stop) ? opts[:auto_stop] : true
    Thread.abort_on_exception = true

    # Make sure that thread pool for defers is 1
    # so that it acts as a simple run loop.
    EM.threadpool_size = 1

    EM.run do
      Thread.new do
        blk.call
        stop_em_when_all_defers_are_done if auto_stop
      end
    end
  end

  def instant_stop_em
    EM.next_tick { EM.stop }
  end

  def stop_em_when_all_defers_are_done
    stop_em = lambda {
      # Account for defers/timers made from within defers/timers
      if EM.defers_finished? && em_timers_finished?
        EM.stop
      else
        # Note: If we put &stop_em in a oneshot timer
        # calling EM.stop does not stop EM; however,
        # calling EM.stop in the next tick does.
        # So let's just do next_tick...
        EM.next_tick(&stop_em)
      end
    }
    EM.next_tick(&stop_em)
  end

  def em_timers_finished?
    all_timers = EM.instance_variable_get("@timers")
    active_timers = all_timers.select { |tid, t| t.respond_to?(:call) }
    active_timers.empty?
  end

  def em_inspect_timers
    puts EM.instance_variable_get("@timers").inspect
  end

  def fixture_path
    File.expand_path("../../vendor/cloud_controller_ng/spec/fixtures", __FILE__)
  end

  RSpec::Matchers.define :be_recent do |expected|
    match do |actual|
      actual.should be_within(5).of(Time.now)
    end
  end

end

class CF::UAA::Misc
  def self.validation_key(*args)
    raise CF::UAA::TargetError.new('error' => 'unauthorized')
  end
end

Dir[File.expand_path("../../vendor/cloud_controller_ng/spec/support/**/*.rb", __FILE__)].each { |file| require file }

class Shim
  include Rack::Test::Methods
  include VCAP::CloudController
  include VCAP::CloudController::SpecHelper
  include VCAP::CloudController::BrokerApiHelper
  include ModelCreation
  include ModelHelpers
  include TempFileCreator
  include ControllerHelpers
end

# Ensures that entries are not returned ordered by the id field by
# default. Breaks the tests (deliberately) unless we order by id
# explicitly. In sqlite, the default ordering, although not guaranteed,
# is de facto by id. In postgres the order is random unless specified.
class VCAP::CloudController::App
  set_dataset dataset.order(:guid)
end

module CcGhost
  def self.install
    app = Rack::Test::Session.new(Rack::MockSession.new(CcGhost.app))
    WebMock.stub_request(:any, %r{cc-ghost*}).to_return do |request|
      #convert Authorization header to Rack expected var HTTP_AUTHORIZATION
      headers = {'HTTP_AUTHORIZATION' => request.headers.delete('Authorization')}.merge(request.headers)
      response = app.send(request.method, request.uri.path, request.body, headers)
      {body: response.body, headers: response.headers, status: response.status}
    end
  end

  def self.app
    Shim.new.app
  end

  def self.headers_for(user)
    Shim.new.headers_for(user)
  end

  class CcGhostFactory
    def organization(attrs = {})
      VCAP::CloudController::Organization.make(attrs)
    end
    def user(attrs = {})
      VCAP::CloudController::User.make(attrs)
    end
  end
  def self.factory
    CcGhostFactory.new
  end

end
