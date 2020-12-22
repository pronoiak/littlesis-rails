# frozen_string_literal: true

module ApplicationHelper
  def page_title
    title = content_for?(:page_title) ? content_for(:page_title) : ''

    if content_for?(:skip_page_title_suffix)
      title
    elsif title.blank?
      'LittleSis'
    else
      "#{title} - LittleSis"
    end
  end

  def excerpt(text, length=30)
    if text
      break_point = text.index(/[\s.,:;!?-]/, length - 5) || length + 1

      text[0..(break_point - 1)] + (text.length > break_point - 1 ? "..." : "")
    end
  end

  def yes_or_no(value)
    value ? "yes" : "no"
  end

  def notice_if_notice
    raw "<div class='alert alert-success'>#{notice}</div>" if notice
  end

  def notice_or_alert
    return unless flash[:alert] || flash[:notice]

    msg = flash[:alert] || flash[:notice]
    style = flash[:alert].present? ? 'danger' : 'success'

    content_tag(:div, msg, class: "alert alert-#{style}")
  end

  def dismissable_alert(id, class_name = 'alert-info', &block)
    session[:dismissed_alerts] = [] unless session[:dismissed_alerts].kind_of?(Array)

    unless session[:dismissed_alerts].include? id
      content_tag('div', id: id, class: "alert #{class_name} alert-dismissable") do
        content_tag('button', raw('&times;'),
                    'class' => 'ml-2 close',
                    'data-dismiss-id' => id) + capture(&block)
      end
    end
  end

  def dashboard_panel(heading: '', color: 'rgba(0, 0, 0, 0.03)', &block)
    content_tag('div', class: 'card') do
      content_tag('div', heading, class: 'card-header', style: "background-color: #{color}") +
        content_tag('div', class: 'card-body') { capture(&block) }
    end
  end

  def contact_path
    "/contact"
  end

  def current_username
    current_user&.username
  end

  def has_ability?(permission)
    current_user && current_user.has_ability?(permission)
  end

  def facebook_meta
    raw(%i[url type title description image]
          .map { |key| [key, content_for(:"facebook_#{key}")] }
          .delete_if { |(key, val)| val.blank? }
          .map { |(key, val)| "<meta property=\"og:#{key}\" content=\"#{val}\" />" }
          .join(""))
  end

  def paginate_preview(ary, num, path)
    raw("1-#{num} of #{ary.count} :: " + link_to("see all", path))
  end

  def entity_link(entity, name = nil, html_class: nil, html_id: nil)
    name ||= entity.name
    link_to name, concretize_entity_path(entity), class: html_class, id: html_id
  end

  # Input: [References], Integer | nil
  def references_select(references, selected_id = nil)
    return nil if references.nil?
    options_array = references.collect { |r| [r.document.name, r.id] }
    select_tag(
      'reference_existing',
      options_for_select(options_array, selected_id),
      { include_blank: true, class: 'selectpicker', name: 'reference[reference_id]' }
    )
  end

  def user_admin?
    user_signed_in? && current_user.admin?
  end

  def show_donation_banner?
    if APP_CONFIG['donation_banner_display'] == 'everywhere'
      true
    elsif APP_CONFIG['donation_banner_display'] == 'homepage' &&
          controller_name == 'home' &&
          controller.action_name == 'index'
      true
    else
      false
    end
  end

  # honeypot for spam bots
  def very_important_wink_wink
    tag.div :style => 'position: absolute; left: -5000px;', :"aria-hidden" => 'true' do
      text_field_tag 'very_important_wink_wink'
    end
  end

  def math_captcha_fields(math_captcha, label_class: '', input_class: '')
    [
      label_tag('spam_test', raw("Please solve the following math problem: <b> #{math_captcha.question}</b>"), :class => label_class),
      hidden_field_tag('math[number_one]', math_captcha.number_one),
      hidden_field_tag('math[number_two]', math_captcha.number_two),
      hidden_field_tag('math[operation]', math_captcha.operation),
      number_field_tag('math[answer]', nil, min: -20, max: 40, class: input_class)
    ].reduce(&:concat)
  end
end
