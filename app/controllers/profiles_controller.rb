class ProfilesController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    
    params_to_update = user_params.to_h
    if params_to_update[:password].blank? && params_to_update[:password_confirmation].blank?
      params_to_update.delete(:password)
      params_to_update.delete(:password_confirmation)
    end

    if @user.update(params_to_update)
      # Re-sign in the user if key authentication fields changed (e.g., password/email)
      bypass_sign_in(@user) if params_to_update[:password].present? || params_to_update[:email].present?
      redirect_to profile_path, notice: 'Profile was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
