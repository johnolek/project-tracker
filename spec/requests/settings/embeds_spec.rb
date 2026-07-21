require "rails_helper"

RSpec.describe "Settings::Embeds", type: :request do
  context "when signed out" do
    it "redirects the index to the login page" do
      get settings_embeds_path
      expect(response).to redirect_to(login_path)
    end

    it "redirects a create to the login page" do
      post settings_embeds_path, params: { embed_domain: { host: "x.example.com", project_id: 1 } }
      expect(response).to redirect_to(login_path)
    end
  end

  context "when signed in" do
    before { register_passkey(username: "boarder") }

    let(:user) { User.find_by(username: "boarder") }
    let(:organization) { user.default_organization }
    let!(:project) { create(:project, organization: organization) }

    it "lists embed domains for the organization" do
      create(:embed_domain, organization: organization, project: project, host: "listed.example.com")

      get settings_embeds_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("listed.example.com")
    end

    describe "create" do
      it "adds a host → project mapping, normalized to lowercase" do
        expect do
          post settings_embeds_path, params: { embed_domain: { host: "ChessHair.com", project_id: project.id } }
        end.to change(organization.embed_domains, :count).by(1)

        expect(response).to redirect_to(settings_embeds_path)
        expect(organization.embed_domains.last.host).to eq("chesshair.com")
      end

      it "re-renders with 422 for an invalid host" do
        expect do
          post settings_embeds_path, params: { embed_domain: { host: "https://not a host", project_id: project.id } }
        end.not_to change(organization.embed_domains, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects a project from another organization" do
        foreign = create(:project)

        expect do
          post settings_embeds_path, params: { embed_domain: { host: "x.example.com", project_id: foreign.id } }
        end.not_to change(EmbedDomain, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "update" do
      it "changes the mapped project" do
        embed_domain = create(:embed_domain, organization: organization, project: project, host: "map.example.com")
        other = create(:project, organization: organization)

        patch settings_embed_path(embed_domain), params: { embed_domain: { project_id: other.id } }

        expect(response).to redirect_to(settings_embeds_path)
        expect(embed_domain.reload.project).to eq(other)
      end
    end

    describe "destroy" do
      it "removes the mapping" do
        embed_domain = create(:embed_domain, organization: organization, project: project, host: "gone.example.com")

        expect do
          delete settings_embed_path(embed_domain)
        end.to change(organization.embed_domains, :count).by(-1)

        expect(response).to redirect_to(settings_embeds_path)
      end
    end
  end
end
