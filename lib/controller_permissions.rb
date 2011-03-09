require 'set'

## Controller Permissions (ACL style)
# Usage:
#   permit :role, :only => :method
#   permit [:role2, :role3], :except => [:method1, :method2]
#   permit :all
#

module ControllerPermissions 

  def self.append_features(base)
    super
    base.extend(ClassMethods)
    base.send(:include, ControllerPermissions::InstanceMethods)
  end
  
  module ClassMethods
  
    # Make sure that the options to the permit method are valid.
    def validate_option_keys(keys, options={})
      options.each do |opt,params|
        params = [params] unless params.is_a? Array
        case opt when :one_of
          # make sure there is only one param in keys
          matches = params.select { |param| keys.include?(param) }
          if matches.length > 1
            raise "can only pick one of these options: #{matches.inspect}" 
          elsif matches.length == 0
            raise "you must pick at least one of these options: #{params.inspect}"
          end
        end
      end
    end

    # Add a permission rule to this controller.
    #
    # Usage:
    #   permit :action, :only => [:role1, :role2]
    #   permit :DEFAULT, :all
    #   permit :other_action, :all
    #   permit :super_action, :except => [:role3, :role4, role5]
    def permit(roles, options={})

      roles = listize(roles)
      rule = nil

      #puts "+ [permit] roles: #{roles.inspect}, options: #{options.inspect}" # debug

      # deal with :all and :none options (since they're not passed in a hash)
      if options.is_a? Symbol or options == {}
        
        case options
          when :all, {}
            #puts "    - allowing all"
            rule = All.new
          when :none
            #puts "    - allowing none"
            rule = None.new
        end

      else
        
        # check that the options are allowed
        validate_option_keys options.keys, :one_of => [:only, :except]
        
        # create permission rules
        for ruletype, actions in options
          actions = listize(actions)
          #values = options[key]
          #values = [values] if values.is_a? Symbol
          
          case ruletype
            when :only
              rule = Only.new(actions)
            when :except
              rule = Except.new(actions)
          end
        end
      end

      # add the specified rules to the ACL
      for role in roles
        add_to_acl role, rule
      end
      
    end
    
    # define a default rule which matches when no other rules match
    def permit_default(options={})
      permit(:DEFAULT, options)
    end

    # add a rule to the secret ACL that's attached to the Controller's metaclass.
    def add_to_acl(role, rule)
      acl = read_acl
      if acl[role]
        acl[role].merge_rule rule
      else
        acl[role] = rule
      end
    end
    
    # check if a role is permitted to do this action
    def permitted?(role, action_name)
      
      acl = read_acl
      rule = acl[role]
      #puts "  - rule: #{rule.inspect}"
      
      if rule
        
        rule.permitted? action_name
        
      elsif acl[:DEFAULT]
        
        acl[:DEFAULT].permitted? action_name
        
      end
      
    end

    
    # get the secret ACL attached to the controller's metaclass
    def read_acl
      read_inheritable_attribute('acl') || write_inheritable_attribute('acl', {})
    end

    # replace the current ACL with a fresh one.
    def clear_acl!
      write_inheritable_attribute('acl', {})
    end

    
    ############################################
    ## Permission Rule Classes

    # Base class for all permission rules.
    class PermissionRule
      
      attr_reader :meths
    
      def initialize(meths)
        add_methods(meths)
      end

      def add_methods(meths)
        if meths
          @meths ||= Set.new
          @meths.merge(meths)
        end
      end

      def merge_rule(rule)
        raise "rule not good -- sameness violaton" unless rule.is_a? self.class
        add_methods(rule.meths)
      end
      
      def permitted?(method)
        false
      end

      def inspect
        "#<#{self.class.name}, actions=>#{@meths.inspect}>"
      end
      
    end

    
    # "Only" -> Allow only the specified roles
    class Only < PermissionRule
      
      def permitted? method
        @meths.include? method
      end
      
    end

    # "Except" -> Allow all roles except the ones specified
    class Except < PermissionRule
      def permitted? method
        !@meths.include? method
      end
    end

    
    # "All" -> Allow all roles
    class All < PermissionRule
      def initialize; end
      def permitted?(method); true; end
    end

    # "None" -> Don't allow any roles
    class None < PermissionRule
      def initialize; end
      def permitted?(method); false; end
    end

    # Convert some object into a flat list, even if it's not a list.
    def listize(thing)
      
      if thing.is_a? Array
        thing.flatten.compact.uniq
      else
        [thing]
      end
      
    end

  end
  
  module InstanceMethods

    ############################################
    ## Controller Filter
    
    # This filter must be enabled on all controllers that you want access control
    # on. (Or, on the ApplicationController (application_controller.rb) to enable
    # it for all controllers. You can then remove it from the ones that you don't
    # want permission control on by adding "skip_before_filter :permission_control")
    # usage:
    #   before_filter :permission_control
    def permission_control
      #if not protect?(action_name)
      #  return true  
      #end

      roles = roles_for_user
      if roles.nil?
        redirect_to_login
        return
      end

      for role in roles
        role = (role.is_a?(Symbol) ? role : role.to_sym) 
        return true if self.permitted?(role, action_name)
      end
    
      # store current location so that we can come back after the user has logged in
      save_location
      
      # call overwriteable reaction to unauthorized access
      access_denied
      return false 
    end
    
    def permitted?(role, action_name)
      #puts "+ Checking permissions for #{role} for action: #{action_name}" # debug
      self.class.permitted? role, action_name
    end


    ############################################
    ## Redefineable Methods

    # Redefine this method if you want to have special behavior in case the user
    # is not authorized to access this action.
    # The default action is to redirect to the login screen
    # Example uses:
    #   close the current popup window instead of relogging in.
    def access_denied
      @flash[:notice] = "Permission denied."
      redirect_to :controller=>"account", :action =>"access_denied"
    end  

    # Redirect the user to the login screen.
    def redirect_to_login
      redirect_to :controller=>"account", :action =>"login"
    end
    
    # This method returns the roles that the current user has or raises
    # an exception if the user isn't logged in. If you don't save the logged in
    # user in @session[:user], or if their roles aren't called .roles, then you can 
    # redefine this method so that it works with your login mechanism.
    def roles_for_user
      raise "Stub Error: roles_for_user not implemented. Make sure this returns a list of roles."
    end
      
  end
  
end
