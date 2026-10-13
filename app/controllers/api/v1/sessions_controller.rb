module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[show create]

      def show
        user = User.find_by(id: session[:user_id])
        render json: { user: user_json(user), csrf_token: form_authenticity_token }, status: :ok
      end

      def create
        user = User.find_by(email: session_params[:email])&.authenticate(session_params[:password].to_s)
        return invalid_credentials unless user

        reset_session
        session[:user_id] = user.id
        render json: { user: user_json(user), csrf_token: form_authenticity_token }, status: :ok
      end

      def destroy
        reset_session
        render json: { user: nil, csrf_token: form_authenticity_token }, status: :ok
      end

      private

      def session_params
        params.permit(:email, :password)
      end

      def user_json(user)
        user&.as_json(only: %i[id email])
      end

      def invalid_credentials
        render json: { errors: { base: [ "Invalid email or password" ] } }, status: :unauthorized
      end
    end
  end
end
