require File.dirname(__FILE__) + '/test_helper'

include ControllerPermissions
include ViewPermissions

class TestController; def rescue_action(e) raise e end; end

class PermissionsTest < Test::Unit::TestCase
  def setup
    @controller = TestController.new
		@request  = ActionController::TestRequest.new
		@response   = ActionController::TestResponse.new
  end

  def test_setup_worked
    @controller.class_eval <<-END
      permit :all
    END
  end

end
