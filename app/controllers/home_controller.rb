# frozen_string_literal: true

class HomeController < ApplicationController
  include SpamHelper

  before_action :authenticate_user!,
                except: [:dismiss, :index, :flag, :token, :newsletter_signup, :pai_signup, :test]

  skip_before_action :verify_authenticity_token, only: [:pai_signup]

  # [list_id, 'title' ]
  DOTS_CONNECTED_LISTS = [
    [41, 'Paid for politicians'],
    [88, 'Corporate fat cats'],
    [102, 'Revolving door lobbyists'],
    [114, 'Secretive Super PACs'],
    [34, 'Elite think tanks']
  ].freeze

  def dashboard
  end

  # turbo streams ↴

  def dashboard_edits
    render partial: 'dashboard_recent_edits',
           locals: { page: params[:page]&.to_i || 1, user_id: current_user.id }
  end

  def dashboard_maps
    render partial: 'dashboard_maps', locals: { page: params[:page]&.to_i || 1, current_user: current_user }
  end

  # ⮥

  # Sends CSRF token to browser extension
  def token
    if user_signed_in?
      render inline: '<%= csrf_meta_tags %>', layout: false
    else
      head :unauthorized
    end
  end

  def dismiss
    dismiss_alert(params[:id])
  end

  def maps
  end

  def lists
  end

  def index
    redirect_to_dashboard_if_signed_in unless request.env['PATH_INFO'] == '/home'
    @dots_connected = dots_connected
    @carousel_entities = carousel_entities
    @stats = ExtensionRecord.data_summary
    @newsletter_signup = NewsletterSignupForm.new(email: current_user&.email)
  end

  def flag
    if request.post?
      @flag_form = FlagForm.new(flag_params)
      @flag_form.create_flag
      redirect_to home_dashboard_path, notice: 'Your flag message has been sent. Thank you!'
    else
      @flag_form = FlagForm.new(page: request.referer, email: current_user&.email)
    end
  end

  # Adds user newsletter and redirects back to home page.
  #
  # POST /home/newsletter_signup
  #
  def newsletter_signup
    form = NewsletterSignupForm.new(newsletter_signup_params)

    NewsletterSignupJob.perform_later(form.email) if form.valid?

    flash.notice = "Thank you! You've been added to our newsletter."
    redirect_to root_path
  end

  # Alternative method for signing up to our mailing list
  # redirects to 'referrer' if present or 'https://news.littlesis.org'
  # POST /home/pai_signup
  def pai_signup
    return head :forbidden if likely_a_spam_bot

    pai_signup_ip_limit(request.remote_ip)

    unless Rails.env.development?
      NewsletterSignupJob.perform_later(params.fetch('email'))
    end

    if request.headers['referer'].blank?
      redirect_to 'https://news.littlesis.org'
    else
      redirect_to request.headers['referer']
    end
  end

  def test
    head :ok
  end

  private

  def pai_signup_ip_limit(ip)
    ip_cache_key = "pai_signup_request_count_for_#{ip}"

    if Rails.cache.read(ip_cache_key).nil?
      Rails.cache.write(ip_cache_key, 1, :expires_in => 60.minutes)
    else
      count = Rails.cache.read(ip_cache_key) + 1
      if count >= 5
        Rails.logger.warn "#{ip} has submitted too many requests this hour!"
        raise Exceptions::PermissionError
      else
        Rails.cache.write(ip_cache_key, count, :expires_in => 60.minutes)
      end
    end
  end

  def redirect_to_dashboard_if_signed_in
    return redirect_to home_dashboard_path if user_signed_in?
  end

  def carousel_entities
    return unless List.exists?(Rails.application.config.littlesis.fetch(:carousel_list_id))

    Rails.cache.fetch('home_controller_index_carousel_entities', expires_in: 2.hours) do
      List.find(Rails.application.config.littlesis.fetch(:carousel_list_id)).entities.to_a
    end
  end

  def dots_connected
    Rails.cache.fetch('dots_connected_count', expires_in: 2.hours) do
      (Person.count + Org.count).to_s.split('')
    end
  end

  def flag_params
    params.permit(:email, :page, :message).to_h
  end

  def newsletter_signup_params
    params.require(:newsletter_signup_form).permit(:email, :very_important_wink_wink)
  end
end
