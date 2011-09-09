require File.join(File.dirname(__FILE__), "test_helper.rb")

class PathTest < Scope::TestCase
  context "with a custom ecology" do
    setup do
      Ecology.reset

      ENV["ECOLOGY_SPEC"] = "/tmp/some.ecology"
      File.expects(:exist?).with("/tmp/some.ecology").returns(true)
      File.expects(:read).with("/tmp/some.ecology").returns(<<ECOLOGY_CONTENTS)
{
  "application": "SomeApp",
  "paths": {
    "pid_location": "/pid_dir/",
    "whozit_location": "$app/../dir1",
    "whatsit_path": "$cwd/logs",
    "some_other_location": "dir/to/there"
  }
}
ECOLOGY_CONTENTS
      Ecology.read
    end

    should "find an absolute path" do
      assert_equal "/pid_dir/", Ecology.path("pid_location")
    end

    should "find an application-relative path" do
      $0 = "some/path/my_app.rb"
      assert_equal "some/path/../dir1", Ecology.path("whozit_location")
    end

    should "find a cwd-relative path" do
      Dir.expects(:getwd).returns("some/path")
      assert_equal "some/path/logs", Ecology.path("whatsit_path")
    end

  end
end
