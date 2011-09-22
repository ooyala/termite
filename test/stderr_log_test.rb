require File.join(File.dirname(__FILE__), "test_helper.rb")

class EcologyLogTest < Scope::TestCase
  context "with a custom ecology" do
    setup do
      Ecology.reset

      set_up_ecology <<ECOLOGY_CONTENTS
{
  "application": "MyApp",
  "logging": {
    "stdout_level": "warn",
    "stderr_level": "fatal"
  }
}
ECOLOGY_CONTENTS
    end

    context "with a default termite logger" do
      setup do
        @logger = Termite::Logger.new
      end

      should "log fatal errors to STDERR" do
        expect_console_add(STDERR, 2, 'oh no!', :application => "MyApp", :method => :puts, :extra_args => [])
        STDOUT.expects(:puts).never
        @logger.fatal("oh no!")
      end

      should "log warnings to STDOUT" do
        expect_console_add(STDOUT, 4, 'oh no!', :application => "MyApp", :method => :puts, :extra_args => [])
        STDERR.expects(:puts).never
        @logger.warn("oh no!")
      end

    end
  end
end
