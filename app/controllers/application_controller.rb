class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from 'Exceptions::PermissionError' do |exception|
  	render "errors/permission", status: 403
  end

  def auth
    redirect_to "/login" unless user_signed_in?
  end

  def check_permission(name)
    raise Exceptions::PermissionError unless current_user.present? and current_user.has_legacy_permission(name)
  end

  def not_found
    raise ActionController::RoutingError.new('Not Found')
  end
end
