# frozen_string_literal: true

# name: login-reply-unlock
# about: Secure [login] and [reply] tags server-side; includes composer buttons and mask actions.
# version: 1.1.1
# authors: hawchou1995
# url: https://github.com/hawchou1995/login-reply-unlock

enabled_site_setting :secure_tags_enabled

after_initialize do
  begin
    module ::LoginReplyUnlock
      CACHE_TTL = 30.seconds

      def self.guardian_from_tag(tag)
        tag.instance_variable_get(:@guardian) rescue nil
      end

      def self.opts_from_tag(tag)
        tag.instance_variable_get(:@opts) rescue nil
      end

      def self.extract_post_from_tag(tag)
        opts = opts_from_tag(tag)
        opts.is_a?(Hash) ? opts[:post] : nil
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

        cache_key = "login-reply-unlock:replied:v1:u#{user.id}:t#{tid}"
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          Post.where(
            user_id: user.id,
            topic_id: tid,
            post_type: Post.types[:regular],
            deleted_at: nil
          ).limit(1).exists?
        end
      end

      def self.mask_html(type:, locale:, topic_id: nil)
        key =
          case type
          when :login then "secure_tags.login_prompt_html"
          when :reply_logged_in then "secure_tags.reply_prompt_html_logged_in"
          when :reply_anonymous then "secure_tags.reply_prompt_html_anonymous"
          else "secure_tags.login_prompt_html"
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
        guardian = ::LoginReplyUnlock.guardian_from_tag(tag)
        locale = ::LoginReplyUnlock.extract_locale_from_tag(tag)
        guardian&.user.present? ? tag.cooked : ::LoginReplyUnlock.mask_html(type: :login, locale: locale)
      end

      PrettyText::Engine.add_bbcode("reply") do |tag, _val, _content|
        guardian = ::LoginReplyUnlock.guardian_from_tag(tag)
        user = guardian&.user
        locale = ::LoginReplyUnlock.extract_locale_from_tag(tag)

        post = ::LoginReplyUnlock.extract_post_from_tag(tag)
        topic_id = post&.topic_id

        if user.present? && ::LoginReplyUnlock.user_replied_to_topic?(user, topic_id)
          tag.cooked
        else
          user.present? ?
            ::LoginReplyUnlock.mask_html(type: :reply_logged_in, locale: locale, topic_id: topic_id) :
            ::LoginReplyUnlock.mask_html(type: :reply_anonymous, locale: locale, topic_id: topic_id)
        end
      end
    end
  rescue => e
    Rails.logger.error("[login-reply-unlock] plugin init failed: #{e.class} #{e.message}\n#{e.backtrace&.first(20)&.join("\n")}")
  end
end
