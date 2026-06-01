---
title: Coming soon
search:
  exclude: true
---

# This post is coming soon

<div id="coming-soon-body" markdown>
A post you followed a link to hasn't been published yet. Check back shortly.
</div>

<script>
(function () {
  var params = new URLSearchParams(window.location.search);
  var raw = params.get("slug") || "";
  // Only allow the kebab-case shape a real slug can take — never inject arbitrary HTML.
  var slug = raw.replace(/[^a-z0-9-]/gi, "").slice(0, 120);
  var el = document.getElementById("coming-soon-body");
  if (!el) return;
  if (slug) {
    el.innerHTML =
      "The post <code>" + slug + "</code> is in the editorial pipeline and " +
      "will appear at its permanent URL once it goes live. " +
      "This placeholder exists so links can be shared before publication.";
  }
})();
</script>
