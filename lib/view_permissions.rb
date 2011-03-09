require 'action_view/helpers/capture_helper'

module ViewPermissions

private
  include ActionView::Helpers::CaptureHelper

  def listize(thing)
    
    if thing.is_a? Array
      thing.flatten.compact.uniq # smoosh
    else
      [thing]
    end
    
  end

  def smoosh(*whatever)
    whatever.flatten.compact.uniq
  end

  # Convert some object into a flat list, even if it's not a list.
  def display_erb_for_roles(roles_to_check, condition, &block)
    roles_to_check = smoosh(roles_to_check)
    
    roles_for_user = eval '@controller.roles_for_user', block
    raise "Error: Could not retrieve the user's roles (is the permissions plugin setup properly?)" unless roles_for_user

    #puts "[erb_for_roles] roles = #{roles_for_user.inspect}"
    
    for role in roles_to_check
      if condition.call(roles_for_user, role)
        data = capture(&block)
        eval("_erbout", block).concat data
      end
    end
    
    nil
  end
  
public
  def allow(*roles, &block)
    condition = proc do |roles_for_user,role|
      roles_for_user.any?{|r| r === role}
    end
    
    display_erb_for_roles(roles, condition, &block)
  end
  
  def deny(*roles, &block)
    condition = proc do |roles_for_user,role|
      !roles_for_user.any?{|r| r === role}
    end
    
    display_erb_for_roles(roles, condition, &block)
  end
end

