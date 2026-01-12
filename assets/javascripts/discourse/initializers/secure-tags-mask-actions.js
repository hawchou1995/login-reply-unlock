
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.secure_tags_enabled) return;

  function dispatchRealClick(el) {
    if (!el) return false;
    if (el.disabled || el.getAttribute("aria-disabled") === "true") return false;

    const opts = { bubbles: true, cancelable: true, view: window };
    el.dispatchEvent(new MouseEvent("pointerdown", opts));
    el.dispatchEvent(new MouseEvent("mousedown", opts));
    el.dispatchEvent(new MouseEvent("pointerup", opts));
    el.dispatchEvent(new MouseEvent("mouseup", opts));
    el.dispatchEvent(new MouseEvent("click", opts));
    return true;
  }

  function openReplyByClickingButtons({ anchorEl }) {
    const topicPost = anchorEl?.closest?.(".topic-post");
    if (topicPost) {
      const postReplyBtn =
        topicPost.querySelector('button.create.reply-to-post[type="button"]') ||
        topicPost.querySelector('button.reply-to-post.create[type="button"]');

      if (dispatchRealClick(postReplyBtn)) return true;
    }

    const topicReplyBtn =
      document.querySelector('button.create.topic-footer-button[type="button"]') ||
      document.querySelector('button.topic-footer-button.create[type="button"]');

    if (dispatchRealClick(topicReplyBtn)) return true;

    return false;
  }

  api.decorateCooked(
    ($elem) => {
      if (!$elem?.length) return;

      $elem
        .off("click.secureActions")
        .on("click.secureActions", ".d-secure-action", (ev) => {
          ev.preventDefault();
          ev.stopPropagation();

          const a = ev.currentTarget;
          const action = a?.getAttribute("data-action");

          if (action === "login") {
            window.location.href = "/login";
            return;
          }

          if (action !== "reply") return;

          const ok = openReplyByClickingButtons({ anchorEl: a });
          if (!ok) {
            // 兜底：跳回当前 topic
            const topicId =
              Number(a?.closest?.(".d-secure-mask")?.getAttribute?.("data-topic-id")) || 0;
            if (topicId) window.location.href = `/t/${topicId}`;
          }
        });
    },
    { id: "secure-mask-actions", onlyStream: true }
  );
});
