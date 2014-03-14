require "cc_ghost/version"
# require './vendor/cloud_controller_ng/spec/spec_helper'
module CcGhost
  require 'webmock'
  require 'fork'
  require 'rack'

  class Organization < Struct.new(:name, :guid); end
  class User < Struct.new(:guid); end
  class Space < Struct.new(:name, :guid); end

  class TypeFactory
    def organization(obj)
      Organization.new(obj.name, obj.guid)
    end

    def user(obj)
      User.new(obj.guid)
    end

    def space(obj)
      Space.new(obj.name, obj.guid)
    end
  end

  class Ghostroller
    # Create a fork with two-directional IO, which returns values and raises
    # exceptions in the parent process.
    def initialize
      @fork = Fork.new :to_fork, :from_fork do |fork|
        require 'cc_ghost/terrible_dependencies'
        type_factory = TypeFactory.new
        factory = CcGhostFactory.new
        shim = Shim.new
        app = Rack::Test::Session.new(Rack::MockSession.new(shim.app))

        while command_tuple = fork.receive_object
          begin
            command, args = command_tuple
            if command == :request
              response = app.send(args[:method], args[:path], args[:body], args[:headers])
              fork.send_object({body: response.body, headers: response.headers, status: response.status})
            elsif command == :config
              fork.send_object(shim.config)
            elsif command == :factory
              result = factory.send(args[:type], args[:attrs])
              fork.send_object(type_factory.send(args[:type], result))
            else
              raise "UNKNOWN COMMAND #{command} (did you send a string?)"
            end
          rescue => e
            puts "CcGhost: Oh no, things went bad: #{e.message}"
            exit(1)
          end
        end
      end
    end


    def install
      @fork.execute # spawn child process and start executing
      WebMock.stub_request(:any, %r{cc-ghost*}).to_return do |request|
        #convert Authorization header to Rack expected var HTTP_AUTHORIZATION
        headers = {'HTTP_AUTHORIZATION' => request.headers.delete('Authorization')}.merge(request.headers)
        @fork.send_object([:request, {method: request.method, path: request.uri.path, body: request.body, headers: headers}])
        @fork.receive_object
      end
    end

    def uninstall
      @fork.send_object(nil)
    end

    def config
      @fork.send_object([:config])
      @fork.receive_object
    end

    def organization(attrs = {})
      @fork.send_object([:factory, {type: 'organization', attrs: attrs}])
      @fork.receive_object
    end

    def space(attrs = {})
      @fork.send_object([:factory, {type: 'space', attrs: attrs}])
      @fork.receive_object
    end

    def user(attrs = {})
      @fork.send_object([:factory, {type: 'user', attrs: attrs}])
      @fork.receive_object
    end
  end
end


