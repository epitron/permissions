# Copyright (c) 2006 Chris Gahan (chris@ill-logic.com)
# Released under the MIT License.  See the LICENSE file for more details.


require 'controller_permissions'
ActionController::Base.class_eval do
  include ControllerPermissions
end

require 'view_permissions'
ActionView::Base.class_eval do
  include ViewPermissions
end
