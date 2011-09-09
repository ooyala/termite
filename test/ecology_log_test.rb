require File.join(File.dirname(__FILE__), "test_helper.rb")

class EcologyLogTest < Scope::TestCase
  context "with a custom ecology and a logger" do
    setup do
      Ecology.reset

      ENV["ECOLOGY_SPEC"] = "/tmp/some.ecology"
      File.expects(:exist?).with("/tmp/some.ecology").returns(true)
      File.expects(:read).with("/tmp/some.ecology").returns(<<ECOLOGY_CONTENTS)
{
  "application": "MyApp",
  "logging": {
    "default_component": "SplodgingLib",
    "extra_json_fields": {
      "app_group": "SuperSpiffyGroup",
      "precedence": 7
    }
  }
}
ECOLOGY_CONTENTS

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
end
