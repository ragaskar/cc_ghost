require 'spec_helper'
$:.unshift(File.expand_path("../../../vendor/cf-uaa-lib/lib", __FILE__))
require 'uaa'
require 'json'

describe "end to end" do
  class TokenEncoder
    def initialize(config)
      @token_coder = CF::UAA::TokenCoder.new(
        :audience_ids => config[:uaa][:resource_id],
        :skey => config[:uaa][:symmetric_secret],
        :pkey => nil
      )
    end

    def token_for(user)
        "bearer #{@token_coder.encode(
          :user_id => user.guid,
          :email => 'some@email.com',
          :scope => []
        )}"
    end

  end

  it 'should be able to return data' do
    CcGhost::Ghostroller.install
    ghostroller = CcGhost::Ghostroller.get
    config = ghostroller.config
    user = ghostroller.user
    auth_token = TokenEncoder.new(config).token_for(user)
    ghostroller.organization(name: 'foo bar', user_guids: [user.guid])

    response = Typhoeus::Request.get('http://cc-ghost' + '/v2/organizations', headers: {'Authorization' => auth_token})

    result = JSON.parse(response.body)
    result['resources'].first['entity']['name'].should == 'foo bar'
    ghostroller.uninstall
  end
end
