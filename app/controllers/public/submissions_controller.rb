module Public
  class SubmissionsController < ApplicationController
    before_action :set_project

    ALLOWED_TYPES = %w[bug idea].freeze

    def new
      @item = @project.items.new(item_type: "idea")
    end

    def create
      # Honeypot: a filled hidden field means a bot. Pretend success without persisting.
      return redirect_to public_project_path(@project.public_token), notice: submission_notice if params[:website].present?

      @item = @project.items.new(submission_params)
      @item.source = "external"
      @item.status = @project.organization.default_status

      if @item.save
        redirect_to public_project_path(@project.public_token), notice: submission_notice
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_project
      @project = Project.find_by!(public_token: params[:public_token])
    end

    def submission_params
      permitted = params.require(:item).permit(:title, :notes, :item_type, :submitter_name, :submitter_email)
      permitted[:item_type] = "idea" unless ALLOWED_TYPES.include?(permitted[:item_type])
      permitted
    end

    def submission_notice
      "Thanks! Your submission has been received."
    end
  end
end
