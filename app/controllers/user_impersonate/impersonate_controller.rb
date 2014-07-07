require_dependency "user_impersonate/application_controller"

module UserImpersonate
  class ImpersonateController < ApplicationController
    before_action :authenticate_the_user
    before_action :set_user, :user_cannot_be_staff!, only: :create
    before_action :current_user_must_be_staff!, except: ["destroy"]

    helper_method :current_staff

    # Perform the user impersonate action
    # GET /impersonate/user/123
    def create
      impersonate(@user)
      redirect_on_impersonate(@user)
    end

    # Revert the user impersonation
    # DELETE /impersonation/revert
    def destroy
      unless current_staff_user
        flash[:notice] = "You weren't impersonating anyone"
        redirect_on_revert and return
      end
      user = current_staff
      revert_impersonate
      if user
        flash[:notice] = "No longer impersonating #{user}"
        redirect_on_revert(user)
      else
        flash[:notice] = "No longer impersonating a user"
        redirect_on_revert
      end
    end

    private

    def current_staff
      @current_staff ||= begin
        current_staff_method = config_or_default(:current_staff, "current_user").to_sym
        send(current_staff_method) if respond_to? current_staff_method
      end
    end

    def current_user_must_be_staff!
      unless user_is_staff?(current_staff)
        redirect_back(fallback_location: '/', error: "You don't have access to this section.")
      end
    end

    def set_user
      @user ||= find_user params[:user_id]
    end

    def user_cannot_be_staff!
      if user_is_staff?(@user)
        flash[:error] = "You cannot impersonate other admins."
        redirect_to :back
      end
    rescue ActionController::RedirectBackError
      redirect_to '/'
    end

    # current_user changes from a staff user to
    # +new_user+; current user stored in +session[:staff_user_id]+
    def impersonate(new_user)
      session[:staff_user_id] = current_user.id
      sign_in_user new_user
    end

    # revert the +current_staff+ back to the staff user
    # stored in +session[:staff_user_id]+
    def revert_impersonate
      return unless current_staff_user
      sign_out_user current_user
      sign_in_user current_staff_user
      session[:staff_user_id] = nil
    end

    def sign_out_user(user)
      # Only need to sign out if the staff class is different to the
      # user being impersonated
      if user_class_name != staff_class_name
        method = config_or_default :sign_out_user_method, "sign_out"
        self.send(method.to_sym, user)
      end
    end

    def sign_in_user(user)
      method = config_or_default :sign_in_user_method, "sign_in"
      self.send(method.to_sym, user)
    end

    def authenticate_the_user
      method = config_or_default :authenticate_user_method, "authenticate_user!"
      self.send(method.to_sym)
    end

    # Helper to load a User, using all the UserImpersonate config options
    def find_user(id)
      user_class.send(user_finder_method, id)
    end

    # Similar to user.staff?
    # Using all the UserImpersonate config options
    def user_is_staff?(user)
      user.respond_to?(user_is_staff_method.to_sym) &&
        user.send(user_is_staff_method.to_sym)
    end

    def user_finder_method
      (config_or_default :user_finder, "find").to_sym
    end

    def user_class_name
      config_or_default :user_class, "User"
    end

    def user_class
      user_class_name.constantize
    end

    def user_table
      user_class.table_name
    end

    def user_id_column
      config_or_default :user_id_column, "id"
    end

    def user_name_column
      config_or_default :user_name_column, "name"
    end

    def user_is_staff_method
      config_or_default :user_is_staff_method, "staff?"
    end

    def staff_class_name
      config_or_default :staff_class, "User"
    end

    def redirect_on_impersonate(impersonated_user)
      url = config_or_default :redirect_on_impersonate, main_app.root_url
      redirect_to url
    end

    def redirect_on_revert(impersonated_user = nil, redirect_params = params)
      url = config_or_default :redirect_on_revert, main_app.root_url
      redirect_to url, {}.merge(redirect_params.permit) # NOTE: not sure at this point what params does it need.
    end

    # gets overridden config value for engine, else returns default
    def config_or_default(attribute, default)
      attribute = attribute.to_sym
      if UserImpersonate::Engine.config.respond_to?(attribute)
        value = UserImpersonate::Engine.config.send(attribute)
        value.respond_to?(:call) ? value.call(self) : value
      else
        default
      end
    end
  end
end
