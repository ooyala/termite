require File.join(File.dirname(__FILE__), "test_helper.rb")

class LevelTest < Scope::TestCase
  context "without termite ecology" do
    setup do
      @logger = Termite::Logger.new(:level => "error")
    end

    should "correctly set level to error" do
      assert_equal Logger::ERROR, @logger.level
    end
  end

  context "with termite ecology" do
    setup do
      Ecology.reset

      set_up_ecology <<ECOLOGY_TEXT
{
  "application": "foo_app",
  "logging":
    {
      "default_component": "whatcomponent",
      "level": "info"
    }
}
ECOLOGY_TEXT
    end

    context "and no overrides" do
      setup do
        @logger = Termite::Logger.new
      end

      should "correctly have level set at info" do
        assert_equal Logger::INFO, @logger.level
      end
    end

    context "and debug overriding at env level" do
      setup do
        ENV["TERMITE_DEBUG"] = "1"
        @logger = Termite::Logger.new()
      end

      should "correctly have level set at debug" do
        assert_equal Logger::DEBUG, @logger.level
      end

    end

  end
end
