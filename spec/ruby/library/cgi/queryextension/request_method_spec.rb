require_relative '../../../spec_helper'

ruby_version_is ""..."3.5" do
  require 'cgi'

  describe "CGI::QueryExtension#request_method" do
    before :each do
      ENV['REQUEST_METHOD'], @old_request_method = "GET", ENV['REQUEST_METHOD']
      @cgi = CGI.new
    end

    after :each do
      ENV['REQUEST_METHOD'] = @old_request_method
    end

    it "returns ENV['REQUEST_METHOD']" do
      old_value, ENV['REQUEST_METHOD'] = ENV['REQUEST_METHOD'], "GET"
      begin
        @cgi.request_method.should == "GET"
      ensure
        ENV['REQUEST_METHOD'] = old_value
      end
    end
  end
end
