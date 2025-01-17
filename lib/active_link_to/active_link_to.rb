# frozen_string_literal: true

module ActiveLinkTo
  ACTIVE_OPTIONS = %i[active
                      class_active
                      class_inactive
                      active_disable
                      wrap_tag
                      wrap_class].freeze
  # Wrapper around link_to. Accepts following params:
  #   :active         => Boolean | Symbol | Regex | Controller/Action Pair
  #   :class_active   => String
  #   :class_inactive => String
  #   :active_disable => Boolean
  #   :wrap_tag       => Symbol
  # Example usage:
  #   active_link_to('/users', class_active: 'enabled')
  #   active_link_to(users_path, active: :exclusive, wrap_tag: :li)
  def active_link_to(name = nil, options = nil, html_options = nil, &block)
    if block_given?
      html_options = options
      options = name
      name = capture(&block)
    end
    options ||= {}
    html_options ||= {}
    active_options = {}
    link_options = {}
    html_options.each do |k, v|
      if ACTIVE_OPTIONS.include?(k)
        active_options[k] = v
      else
        link_options[k] = v
      end
    end

    url = url_for(options)

    css_class = link_options.delete(:class)
    wrap_tag  = active_options[:wrap_tag]

    active = is_active_link?(url, active_options[:active])
    active_class = active_link_to_class(url, active_options)
    link_options['aria-current'] ||= 'page' if active
    link_options[:class] = "#{css_class} #{active_class}".strip

    link = if active_options[:active_disable] == true && active
             content_tag(:span, name, link_options)
           else
             link_to(name, url, link_options)
           end
    if wrap_tag.present?
      wrap_html_options = {
        class: "#{active_options[:wrap_class]} #{active_class}".strip
      }
      content_tag(wrap_tag, link, wrap_html_options)
    else
      link
    end
  end

  # Returns css class name. Takes the link's URL and its params
  # Example usage:
  #   active_link_to_class('/root', class_active: 'on', class_inactive: 'off')
  #
  def active_link_to_class(url, options = {})
    if is_active_link?(url, options[:active])
      options[:class_active] || 'active'
    else
      options[:class_inactive].to_s
    end
  end

  # Returns true or false based on the provided path and condition
  # Possible condition values are:
  #                  Boolean -> true | false
  #                   Symbol -> :exclusive | :inclusive
  #                    Regex -> /regex/
  #   Controller/Action Pair -> [[:controller], [:action_a, :action_b]]
  #
  # Example usage:
  #
  #   is_active_link?('/root', true)
  #   is_active_link?('/root', :exclusive)
  #   is_active_link?('/root', /^\/root/)
  #   is_active_link?('/root', ['users', ['show', 'edit']])
  #
  def is_active_link?(url, condition = nil)
    @is_active_link ||= {}
    @is_active_link[[url, condition]] ||= begin
      case condition
      when :exclusive, :inclusive, nil
        url_path = url.split('#').first.split('?').first
        url_string = URI.parser.unescape(url_path).force_encoding(Encoding::BINARY)
        request_uri = URI.parser.unescape(request.path).force_encoding(Encoding::BINARY)
        if condition == :exclusive
          url_string == request_uri
        else
          closing = url_string.end_with?('/') ? '' : '/'
          url_string == request_uri || request_uri.start_with?(url_string + closing)
        end
      when :exact
        request.original_fullpath == url
      when Regexp
        request.original_fullpath.match(condition).present?
      when Array
        controllers = [*condition[0]]
        actions     = [*condition[1]]
        (controllers.blank? || controllers.member?(params[:controller])) &&
          (actions.blank? || actions.member?(params[:action])) ||
          controllers.any? do |controller, action|
            params[:controller] == controller.to_s && params[:action] == action.to_s
          end
      when TrueClass, FalseClass
        condition
      when Hash
        condition.all? do |key, value|
          params[key].to_s == value.to_s
        end
      end
    end
  end
end

ActiveSupport.on_load :action_view do
  include ActiveLinkTo
end
