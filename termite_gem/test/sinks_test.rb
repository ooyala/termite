require File.join(File.dirname(__FILE__), "test_helper.rb")

class SinksTest < Scope::TestCase
  context "with a hastur sink ecology" do
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
    "sinks": [
      {
        "type": "syslog",
        "transport": "UDP"
      },
      {
        "type": "hastur",
        "labels": {
          "hi": "lo",
          "fast": "slo"
        }
      }
    ]
  }
}
ECOLOGY_CONTENTS
    end

    context "with a default termite logger" do
      setup do
        @hastur_mock = mock("Hastur Logger")
        Termite::HasturLogger.expects(:new).returns(@hastur_mock)
        @logger = Termite::Logger.new
      end

      should "send back extra JSON data and a default component when specified" do
        @hastur_mock.expects(:send_message).with(4, 'oh no!', {:combined => "MyApp:SplodgingLib", :app => "MyApp", :component => "SplodgingLib"}, anything, '{"app_group":"SuperSpiffyGroup","precedence":7}')
        @logger.fatal("oh no!")
      end

      should "allow overriding the default component" do
        @hastur_mock.expects(:send_message).with(4, 'oh no!', {:combined => "MyApp:SpliyingLib", :app => "MyApp", :component => "SpliyingLib"}, anything, '{"app_group":"SuperSpiffyGroup","precedence":7}')
        @logger.fatal("oh no!", {}, :component => "SpliyingLib")
      end

      should "allow overriding the default component with nothing" do
        @hastur_mock.expects(:send_message).with(4, 'oh no!', {:combined => nil, :app => "MyApp", :component => nil}, anything, '{"app_group":"SuperSpiffyGroup","precedence":7}')
        @logger.fatal("oh no!", {}, :component => nil)
      end
    end
  end

  context "with a sinked UDP ecology" do
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
    "sinks": [
      {
        "type": "syslog",
        "transport": "UDP"
      }
    ]
  }
}
ECOLOGY_CONTENTS
    end

    context "with a default termite logger" do
      setup do
        @logger = Termite::Logger.new
      end

      should "send back extra JSON data and a default component when specified" do
        expect_udp(@logger.socket, 2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp:SplodgingLib")
        @logger.fatal("oh no!")
      end

      should "allow overriding the default component" do
        expect_udp(@logger.socket, 2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp:SpliyingLib")
        @logger.fatal("oh no!", {}, :component => "SpliyingLib")
      end

      should "allow overriding the default component with nothing" do
        expect_udp(@logger.socket, 2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp")
        @logger.fatal("oh no!", {}, :component => nil)
      end
    end
  end

  context "with a sinked ecology" do
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
    "sinks": [
      {
        "type": "stdout",
        "color": "green",
        "min_level": "debug",
        "max_level": "warn"
      },
      {
        "type": "stderr",
        "color": "red",
        "min_level": "error"
      },
      {
        "type": "file",
        "filename": "/tmp/bobo.txt",
        "min_level": "warn",
        "shift_age": 10,
        "shift_size": 1024000
      },
      {
        "type": "syslog"
      }
    ]
  }
}
ECOLOGY_CONTENTS
    end

    context "with a default termite logger" do
      setup do
        @logger = Termite::Logger.new
      end

      should "send back extra JSON data and a default component when specified" do
        expect_add(2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp:SplodgingLib")
        @logger.fatal("oh no!")
      end

      should "allow overriding the default component" do
        expect_add(2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp:SpliyingLib")
        @logger.fatal("oh no!", {}, :component => "SpliyingLib")
      end

      should "allow overriding the default component with nothing" do
        expect_add(2, 'oh no! {"app_group":"SuperSpiffyGroup","precedence":7}', :application => "MyApp")
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
      ::Logger.expects(:new).with("/var/lib/sam.log", "daily", 1048576).returns(log_mock)
      Termite::Logger.new("/var/lib/sam.log", "daily")
    end
  end
end
