module WPlatformAuthentication
  require 'net/https'

  def initialize_user_sessions
    session[:w_token] = params[:token_string]
    session[:user_log_id] = params[:user_log_id]
    session[:company_permalink] = params[:permalink]
    request_user_features_from_token_and_company_permalink(session[:w_token], session[:company_permalink])
  end

  def has_complete_params?
    rv = true
    if params[:token_string].blank? or params[:user_log_id].blank? or params[:permalink].blank?
      rv = false
    end
    rv
  end

  def call_w_platform_api(api_address)
    begin
      Rails.logger.info "\n\n*****\n Requesting to API :#{api_address}\n\n"

      url = URI.parse(api_address)

      if WPlatformConfig.protocol == "http"
        if api_address.include?("how_to?hash_name=")
          req = Net::HTTP::Get.new(url.request_uri)
        else
          req = Net::HTTP::Get.new(url.path)
        end
        res = Net::HTTP.start(url.host, url.port) {|http| http.request(req)}
      else
        req = Net::HTTP.new(url.host, url.port)
        req.use_ssl = true
        req.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http = Net::HTTP::Get.new(url.request_uri)
        res = req.request(http)
      end
      ActiveSupport::JSON.decode(res.body)

    rescue => e
      Rails.logger.info "\n\n*****Something Wrong when access API :#{api_address}\n\n ****Error: #{e.inspect}"
      puts "\n\n*****Something Wrong when access API :#{api_address}\n\n ****Error: #{e.inspect}"
      ""
    end
  end

  def access_skipped_controllers?(skipped_controllers, controller_name, action_name="index")
    rv = false
    default_skipped = [
      {:controller_name => "authentication/session_receivers", :action_name => "index"},
      {:controller_name => "authentication/session_cleaners", :action_name => "new"}
    ]
    skipped_controllers += default_skipped
    skipped_controllers.each do |controller|
      if controller[:controller_name] == controller_name and controller[:action_name] == action_name
        rv = true
      end
    end
    rv
  end

  def request_user_features_from_token_and_company_permalink(token, company_permalink)
    api_address = "#{WPlatformConfig.appschef_url}/api/users/#{token}/#{WPlatformConfig.api_key}/#{company_permalink}"
    result = call_w_platform_api(api_address)
    if result and result['user']
      user_data = result['user']
      session[:features] = user_data['features']
      session[:company_products] = user_data['company_products']
      session[:company] = user_data['user_company']
      session[:products] = user_data['products']
      user = { 'first_name' => user_data['first_name'],
        'last_name' => user_data['last_name'],
        'email' => user_data['email'],
        'login_time' => user_data['login_time']
      }
      session[:user_platform] = user
    end
  end

  def has_active_sessions?
    active = false
    if has_complete_sessions?

      api_address = "#{WPlatformConfig.appschef_url}/api/users/already_logged_out/#{session[:user_log_id]}/#{session[:company_permalink]}/#{WPlatformConfig.api_key}"
      result = call_w_platform_api(api_address)

      if result and result["already_logged_out"] and result["already_logged_out"] == "false"
        active = true
      end
    end
    active
  end

  def user_has_access_to?(controller_name, action_name)
    has_access = false
    controller_name = controller_name.gsub("/", "_") if controller_name.include?("/")

    if WPlatformFeature.method_defined?(controller_name.to_sym) and (key_group = WPlatformFeature[controller_name])
      if !key_group.blank? and !key_group[action_name].blank? and !current_features.blank? and current_features.include?(key_group[action_name])
        has_access = true
      end
    end
    has_access
  end

  def assign_controller_and_action_name
    controller_name = params[:controller]
    action_name = params[:action]

    if controller_name and controller_name == "/"
      controller_name = WPlatformConfig.root_controller
      action_name = WPlatformConfig.root_action
    else
      if controller_name and action_name.blank?
        action_name = "index"
      end
    end

    return controller_name, action_name
  end

  def has_complete_sessions?
    rv = true
    if session[:company_permalink].blank? or session[:features].blank? or session[:user_platform].blank? or session[:company].blank?
      rv = false
    end
    rv
  end

  def get_active_session_or_back_to_platform
    url = "#{WPlatformConfig.appschef_url}#{WPlatformConfig.w_api_url_get_active_session}"
    params_string = "?service=#{WPlatformConfig.app_name}&continue=#{WPlatformConfig.app_url}/a/#{session[:company_permalink]}"
    redirect_to "#{url}#{params_string}"
  end

  #modified by hendrik
  def logout_and_back_to_platform(logout_from_platform=true)
    if logout_from_platform and has_complete_sessions?
      w_token = session[:w_token]
      session[:w_token] = nil
      session[:user_log_id] = nil
      session[:company_permalink] = nil
      session[:features] = nil
      session[:user_platform] = nil
      session[:company] = nil
      redirect_to "#{WPlatformConfig.appschef_url}#{WPlatformConfig.w_api_url_users}#{w_token}/logout/#{WPlatformConfig.api_key}"
    else
      redirect_to "#{WPlatformConfig.appschef_url}#{WPlatformConfig.w_api_url_get_active_session}"
    end
  end
  
  #added by hendrik
  def get_user_list()
    users = {}
    token = session[:w_token]
    company_permalink = session[:company_permalink]
    api_address = "#{WPlatformConfig.appschef_url}/api/users/#{token}/#{WPlatformConfig.api_key}/user_list/#{company_permalink}"
    result = call_w_platform_api(api_address)
    if result 
      users = result          
    end
    users
  end

end
