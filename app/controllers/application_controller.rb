class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection

  protect_from_forgery with: :exception
  before_action :authenticate_user!

  rescue_from ActionController::InvalidAuthenticityToken, with: :render_invalid_csrf_token

  private

  attr_reader :current_user

  def authenticate_user!
    @current_user = User.find_by(id: session[:user_id])
    return if @current_user

    render json: { errors: { base: [ "Authentication required" ] } }, status: :unauthorized
  end

  def render_invalid_csrf_token
    render json: { errors: { base: [ "Invalid CSRF token" ] } }, status: :unprocessable_entity
  end
end
