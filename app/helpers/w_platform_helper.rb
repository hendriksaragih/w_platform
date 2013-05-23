module WPlatformHelper
  include WPlatformAuthentication

  def current_user_platform
    user = {}
    unless session[:user_platform].blank?
      user = session[:user_platform]
    end
    user
  end

  def current_company_products
    company_products = {}
    unless session[:company_products].blank?
      company_products = session[:company_products]
    end
    company_products
  end

  def current_products
    products = {}
    unless session[:products].blank?
      products = session[:products]
    end
    products
  end

  def current_company
    company = {}
    unless session[:company].blank?
      company= session[:company]
    end
    company
  end

  def current_features
    features = {}
    unless session[:features].blank?
      features = session[:features].collect{|x| x["key"]}
    end
    features
  end

  #modified by hendrik
  def check_user_access(skipped_controllers_actions=[])
    controller_name, action_name = assign_controller_and_action_name
    unless access_skipped_controllers?(skipped_controllers_actions, controller_name, action_name)
      if has_active_sessions?
        unless user_has_access_to?(controller_name, action_name)
          if controller_name == WPlatformConfig.root_controller and action_name ==  WPlatformConfig.root_action
            back_url = request.referer.blank? ? WPlatformConfig.appschef_url : request.referer
            redirect_to back_url          
          end
        end

      else
        logout_and_back_to_platform(false)
      end

    end

  end
  
  #added by hendrik
  def get_api_user_list_platform
    get_user_list()
  end
  
end
