require File.join(File.dirname(__FILE__), "test_helper.rb")

class SubLogger < Termite::Logger
end

class TermiteSubclassTest < Scope::TestCase
  context "with subclassed termite" do
    setup do
      Ecology.reset

      set_up_ecology <<ECOLOGY_TEXT
{
  "application": "foo_app"
}
ECOLOGY_TEXT
    end

    context "and only default logging levels set" do
      setup do
        @logger = SubLogger.new
      end

      should "correctly send logs to Syslog" do
        expect_add(2, "foo! {}", :application => "foo_app")
        @logger.add(Logger::FATAL, "foo!", {})
      end
    end
  end
end
