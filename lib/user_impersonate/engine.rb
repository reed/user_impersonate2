module UserImpersonate
  class Engine < ::Rails::Engine
    isolate_namespace UserImpersonate

    initializer "user_impersonate.devise_helpers" do
      if Object.const_defined?("Devise")
        require "user_impersonate/devise_helpers"
        Devise.include_helpers(UserImpersonate::DeviseHelpers)
      end
    end

    initializer "user_impersonate.helpers" do
      ActiveSupport.on_load(:action_controller) do
        ActionController::Base.helper(UserImpersonate::ApplicationHelper)
        ActionController::Base.send(:include, UserImpersonate::ApplicationHelper)
      end
    end
  end
end
