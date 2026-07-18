module Api
  module V1
    class ProjectsController < BaseController
      before_action :set_project, only: %i[show update destroy]

      def index
        projects = current_organization.projects.order(:name)
        render json: { projects: projects.map { |project| ProjectSerializer.render(project) } }
      end

      def show
        render json: ProjectSerializer.render(@project)
      end

      def create
        project = current_organization.projects.create!(project_params)
        render json: ProjectSerializer.render(project), status: :created
      end

      def update
        @project.update!(project_params)
        render json: ProjectSerializer.render(@project)
      end

      def destroy
        @project.destroy!
        head :no_content
      end

      private

      def set_project
        @project = current_organization.projects.find(params[:id])
      end

      def project_params
        params.require(:project).permit(:name, :slug)
      end
    end
  end
end
