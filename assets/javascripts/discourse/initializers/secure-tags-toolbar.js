
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.secure_tags_enabled) return;

  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "secure_tags_insert_login",
      group: "extras",
      icon: "lock",
      title: "secure_tags.toolbar.insert_login.title",
      perform: (e) => {
        e.applySurround(
          "[login]\n",
          "\n[/login]",
          "secure_tags.toolbar.insert_login.placeholder"
        );
      },
    });

    toolbar.addButton({
      id: "secure_tags_insert_reply",
      group: "extras",
      icon: "comment",
      title: "secure_tags.toolbar.insert_reply.title",
      perform: (e) => {
        e.applySurround(
          "[reply]\n",
          "\n[/reply]",
          "secure_tags.toolbar.insert_reply.placeholder"
        );
      },
    });
  });
});
