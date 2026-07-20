# Be sure to restart your server when you modify this file.

# Baseline CSP (PROJ-76). The app renders API-authored rich text, so this is
# the backstop for any future sanitizer gap: no external scripts, no framing.
# unsafe_inline styles are required by Bulma helpers and the per-type color
# style attributes on chips; there are no inline scripts anywhere.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :blob
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self
    policy.base_uri    :self
    policy.frame_ancestors :self
  end
end
