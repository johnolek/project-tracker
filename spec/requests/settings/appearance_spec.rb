require "rails_helper"

RSpec.describe "Settings appearance (PROJ-32)", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:user) { User.find_by(username: "owner") }

    it "renders the ThemeSettings island with the schemes and current choices" do
      get edit_settings_appearance_path

      expect(response).to have_http_status(:ok)
      props = Nokogiri::HTML(response.body).at_css('[data-svelte-component="ThemeSettings"]')["data-props"]
      parsed = JSON.parse(props)

      expect(parsed["colorScheme"]).to eq("southwest")
      expect(parsed["themeMode"]).to eq("auto")
      expect(parsed["schemes"].map { |scheme| scheme["key"] }).to eq(%w[southwest mesa-verde gulf adobe-dusk])
    end

    it "persists a scheme and mode choice as JSON" do
      patch settings_appearance_path, params: { user: { color_scheme: "gulf", theme_mode: "dark" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.color_scheme).to eq("gulf")
      expect(user.theme_mode).to eq("dark")
    end

    it "rejects an unknown scheme" do
      patch settings_appearance_path, params: { user: { color_scheme: "vaporwave" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.color_scheme).to eq("southwest")
    end

    it "applies the chosen scheme and mode to the page shell" do
      patch settings_appearance_path, params: { user: { color_scheme: "mesa-verde", theme_mode: "light" } }, as: :json
      get root_path

      html = Nokogiri::HTML(response.body).at_css("html")
      expect(html["data-color-scheme"]).to eq("mesa-verde")
      expect(html["data-theme"]).to eq("light")
      expect(response.body).to include('<meta name="theme-color" content="#2a6f4d">')
    end
  end

  it "requires login" do
    get edit_settings_appearance_path

    expect(response).to redirect_to(login_path)
  end
end
