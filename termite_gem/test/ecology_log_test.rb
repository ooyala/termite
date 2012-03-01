require File.join(File.dirname(__FILE__), "test_helper.rb")

class EcologyLogTest < Scope::TestCase
  context "with a custom ecology" do
    setup do
      Ecology.reset

      set_up_ecology <<ECOLOGY_CONTENTS
{
  "application": "MyApp",
  "logging": {
    "default_component": "SplodgingLib",
    "extra_json_fields": {
      "app_group": "SuperSpiffyGroup",
      "precedence": 7
    },
    "console_print": "off",
    "filename": "/tmp/bobo.txt",
    "shift_age": 10,
    "shift_size": 1024000
  }
}
ECOLOGY_CONTENTS
    end

    context "with a default termite logger" do
      setup do
        @logger = Termite::Logger.new
      end

      should "send back extra JSON data and a default component when specified" do
        expect_add(@logger.socket, 2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp:SplodgingLib")
        @logger.fatal("oh no!")
      end

      should "allow overriding the default component" do
        expect_add(@logger.socket, 2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp:SpliyingLib")
        @logger.fatal("oh no!", {}, :component => "SpliyingLib")
      end

      should "allow overriding the default component with nothing" do
        expect_add(@logger.socket, 2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp")
        @logger.fatal("oh no!", {}, :component => nil)
      end
    end

    should "pass initialize parameters to Ruby Logger" do
      log_mock = mock("Ruby Logger")
      ::Logger.expects(:new).with("/tmp/bobo.txt", 10, 1024000).returns(log_mock)
      Termite::Logger.new
    end

    should "override parameters passed to Termite Logger" do
      log_mock = mock("Ruby Logger")
      ::Logger.expects(:new).with("/tmp/bobo.txt", 10, 1024000).returns(log_mock)
      Termite::Logger.new("/var/lib/sam.log", "daily")
    end
  end
end
