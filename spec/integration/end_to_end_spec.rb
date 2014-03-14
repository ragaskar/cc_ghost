require 'spec_helper'

describe "end to end" do
  it 'should be able to return data' do
    CcGhost.install
    factory = CcGhost.factory
    user = factory.user
    factory.organization(name: 'foo bar', user_guids: [user.guid])
    auth_token = CcGhost.headers_for(user)['HTTP_AUTHORIZATION']

    response = Typhoeus::Request.get('http://cc-ghost'+ '/v2/organizations', headers: {'Authorization' => auth_token})

    result = JSON.parse(response.body)
    result['resources'].first['entity']['name'].should == 'foo bar'
  end
end
