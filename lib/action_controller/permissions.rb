require 'set'

## Access Control List
# Usage:
#   permit :user, :only => :method
#   permit [:user2, :user3], :except => [:method1, :method2]
#   permit :all
#

module Epi
  module Permissions 
    def self.append_features(base)
      super
      base.extend(ClassMethods)
      base.send(:include, Epi::Permissions::InstanceMethods)
    end
    
    module ClassMethods
      def validate_option_keys(keys, options={})
        options.each do |opt,params|
          params = [params] unless params.is_a? Array
          case opt
            when :one_of
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

      #def permit(roles, options={})
      def permit(*params)

        puts "+ permit(#{params.inspect})"
      
        options = {}
        options = params.pop if params[-1].is_a? Hash

        roles = params
        
        rule = nil

        # deal with :all and :none options (since they're not passed in a hash)
        if options.is_a? Symbol or options == {}
          
          case options
            when :all, {}
              rule = All.new
            when :none
              rule = None.new
          end

        else
          
          # check that the options are allowed
          validate_option_keys options.keys, :one_of => [:only, :except]
          
          # create permission rules
          for key in options.keys
            values = options[key]
            values = [values] if values.is_a? Symbol
            
            case key
              when :only
                rule = Only.new(values)
              when :except
                rule = Except.new(values)
            end
          end
        end

        # add rules to the ACL
        for role in roles
          add_to_acl role, rule
        end
        
      end
      
      
      def permit_default(options={})
        permit(:DEFAULT, options)
      end

      
      def add_to_acl(role, rule)
        acl = read_acl
        if acl[role]
          acl[role].merge_rule rule
        else
          acl[role] = rule
        end
      end
      

      def permitted?(role, methodname)
        
        acl = read_acl
        
        if acl[role]
          
          acl[role].permitted? methodname
          
        elsif acl[:DEFAULT]
          
          acl[:DEFAULT].permitted? methodname
          
        end
        
      end

      
      def read_acl
        
        read_inheritable_attribute('acl') || write_inheritable_attribute('acl', {})
        
      end

      def clear_acl!
        
        write_inheritable_attribute('acl', {})
        
      end

      
      ## Permission Rules ##

      class PermissionRule
        
        attr_reader :meths
      
        def initialize(meths)
          add_methods(meths)
        end

        def add_methods(meths)
          @meths ||= Set.new
          @meths.merge(meths)
        end

        def merge_rule(rule)
          raise "rule not good -- sameness violaton" unless rule.is_a? self.class
          add_methods(rule.meths)
        end
        
        def permitted?(method)
          false
        end
        
      end

      
      class Only < PermissionRule
        
        def permitted? method
          @meths.include? method
        end
        
      end

      
      class Except < PermissionRule
        
        def permitted? method
          !@meths.include? method
        end
        
      end

      
      class All < PermissionRule
        
        def initialize
        end
          
        def permitted? method
          true
        end
        
      end

      class None < PermissionRule
        
        def initialize
        end
              
        def permitted? method
          false
        end
        
      end

      def listize(thing)
        
        if thing.is_a? Array
          thing.flatten
        else
          [thing]
        end
        
      end

    end
    
    module InstanceMethods
      
      #### authorization filter ### 
      # usage:
      #   before_filter :permission_control
      def permission_control
        #if not protect?(action_name)
        #  return true  
        #end

        puts "+ Checking permissions for #{action_name}"
        
        if @session[:user]
          for role in @session[:user].roles
            role_to_check = role.name.to_sym
            puts "  - checking #{role_to_check.inspect}"
            return true if permitted? role_to_check, action_name
          end
        end
      
        # store current location so that we can come back after the user has logged in
        save_location
        
        # call overwriteable reaction to unauthorized access
        access_denied
        return false 
      end
      
      def permitted?(role, methodname)
        puts "+ Checking permissions for #{role} on method: #{methodname}"
        self.class.permitted? role, methodname
      end

      # overwrite this method if you only want to protect certain actions of the controller
      # example:
      # 
      #  # don't protect the login and the about method
      #  def protect?(action)
      #  if ['action', 'about'].include?(action)
      #     return false
      #  else
      #     return true
      #  end
      #  end
      def protect?(action)
        true
      end

      # overwrite if you want to have special behavior in case the user is not authorized
      # to access the current operation. 
      # the default action is to redirect to the login screen
      # example use :
      # a popup window might just close itself for instance
      def access_denied
        #@flash[:notice] = "Permission denied."
        redirect_to :controller=>"account", :action =>"login"
      end  
      
    end
    
  end
  
end

