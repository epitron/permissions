# permissions

A permissions plugin for Rails.

It lets you mark specific controller methods as accessible only by users
who are members of specific groups.

## Installing

> script/plugin install git://github.com/epitron/permissions.git

## Usage

This plugin adds the `permit` classmethod to `ActionController::Base`, so that you can
specify permissions in your controllers. It works almost the same as `before_filter`.

    permit(roles, options={})

For example:

    permit :user, :only=>[:show, :index]
    
This rule gives users access to read in your standard CRUD controller.

You can specify multiple `roles` at the same time:

    permit [:admin, :manager]
    
This will permit admin and managers for all actions.

The plugin checks the user's permissions by reading `current_user.roles`
and seeing if any of the roles on the user match the roles on the rule.
If they do, the rule becomes active.

You can specify a rule that applies to all users with the special role `:all`.
  
The `options` you can pass are:

* :only => <symbol or array of symbols> -- only protect specified method(s)
* :except => <symbol or array of symbols> -- protect everything except specified method(s)

## More Examples

Allow all users to access all methods (overrides previous permissions):

    permit :all

Allow the user with role :role to access only the "show" method:

    permit :role, :only => :show
  
Users with the roles :role2 or :role3 can access all methods except
:method1 and :method2.
  
    permit [:role2, :role3], :except => [:method1, :method2]

