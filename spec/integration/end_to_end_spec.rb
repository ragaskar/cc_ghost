require 'spec_helper'

describe "end to end" do
  it 'should be able to return data' do
    factory = CcGhost.factory
    user = factory.user
    factory.organization(name: 'foo bar', user_guids: [user.guid])

    session = Rack::Test::Session.new(Rack::MockSession.new(CcGhost.app))
    session.get '/v2/organizations', {}, CcGhost.headers_for(user)

    result = JSON.parse(session.last_response.body)
    result['resources'].first['entity']['name'].should == 'foo bar'
  end
end
