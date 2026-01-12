# frozen_string_literal: true

# name: discourse-secure-tags
# about: Secure [login] and [reply] tags server-side; includes composer buttons and mask actions.
# version: 1.1.0
# authors: your-name
# url: https://github.com/<yourname>/<yourrepo>

enabled_site_setting :secure_tags_enabled

after_initialize do
  module ::DiscourseSecureTags
    CACHE_TTL = 30.seconds

    def self.guardian_from_tag(tag)
      tag.instance_variable_get(:@guardian) rescue nil
    end

    def self.opts_from_tag(tag)
      tag.instance_variable_get(:@opts) rescue nil
    end

    def self.extract_post_from_tag(tag)
      opts = opts_from_tag(tag)
      return nil unless opts.is_a?(Hash)
      opts[:post]
    end

    def self.extract_locale_from_tag(tag)
      opts = opts_from_tag(tag)
      loc = opts.is_a?(Hash) ? opts[:locale] : nil
      loc.presence || I18n.locale
    end

    def self.user_replied_to_topic?(user, topic_id)
      return false if user.blank?

      tid = topic_id.to_i
      return false if tid <= 0

      cache_key = "secure-tags:replied:v2:u#{user.id}:t#{tid}"
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        Post
          .where(
            user_id: user.id,
            topic_id: tid,
            post_type: Post.types[:regular],
            deleted_at: nil
          )
          .limit(1)
          .exists?
      end
    end

    def self.mask_html(type:, locale:, topic_id: nil)
      key =
        case type
        when :login
          "secure_tags.login_prompt_html"
        when :reply_logged_in
          "secure_tags.reply_prompt_html_logged_in"
        when :reply_anonymous
          "secure_tags.reply_prompt_html_anonymous"
        else
          "secure_tags.login_prompt_html"
        end

      msg = I18n.t(key, locale: locale)

      <<~HTML
        <div class="d-secure-mask"#{topic_id ? " data-topic-id=\"#{topic_id.to_i}\"" : ""}>
          <div class="d-secure-overlay">
            #{msg}
          </div>
        </div>
      HTML
    end
  end

  if SiteSetting.secure_tags_enabled
    PrettyText::Engine.add_bbcode("login") do |tag, _val, _content|
      guardian = ::DiscourseSecureTags.guardian_from_tag(tag)
      locale = ::DiscourseSecureTags.extract_locale_from_tag(tag)

      if guardian&.user.present?
        tag.cooked
      else
        ::DiscourseSecureTags.mask_html(type: :login, locale: locale)
      end
    end

    PrettyText::Engine.add_bbcode("reply") do |tag, _val, _content|
      guardian = ::DiscourseSecureTags.guardian_from_tag(tag)
      user = guardian&.user
      locale = ::DiscourseSecureTags.extract_locale_from_tag(tag)

      post = ::DiscourseSecureTags.extract_post_from_tag(tag)
      topic_id = post&.topic_id

      if user.present? && ::DiscourseSecureTags.user_replied_to_topic?(user, topic_id)
        tag.cooked
      else
        if user.present?
          ::DiscourseSecureTags.mask_html(type: :reply_logged_in, locale: locale, topic_id: topic_id)
        else
          ::DiscourseSecureTags.mask_html(type: :reply_anonymous, locale: locale, topic_id: topic_id)
        end
      end
    end
  end
end
