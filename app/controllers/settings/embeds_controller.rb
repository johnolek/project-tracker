module Settings
  class EmbedsController < ApplicationController
    before_action :require_login
    before_action :set_embed_domain, only: %i[update destroy]

    def index
      @embed_domains = embed_domains_scope
      @embed_domain = current_organization.embed_domains.new
    end

    def create
      @embed_domain = current_organization.embed_domains.new(embed_domain_params)

      if @embed_domain.save
        redirect_to settings_embeds_path, notice: "Embed domain created."
      else
        @embed_domains = embed_domains_scope
        render :index, status: :unprocessable_entity
      end
    end

    def update
      if @embed_domain.update(embed_domain_params)
        redirect_to settings_embeds_path, notice: "Embed domain updated."
      else
        redirect_to settings_embeds_path, alert: @embed_domain.errors.full_messages.to_sentence
      end
    end

    def destroy
      if @embed_domain.destroy
        redirect_to settings_embeds_path, notice: "Embed domain deleted."
      else
        redirect_to settings_embeds_path, alert: @embed_domain.errors.full_messages.to_sentence
      end
    end

    private

    def set_embed_domain
      @embed_domain = current_organization.embed_domains.find(params[:id])
    end

    def embed_domains_scope
      current_organization.embed_domains.includes(:project).order(:host)
    end

    def embed_domain_params
      params.require(:embed_domain).permit(:host, :project_id)
    end
  end
end
