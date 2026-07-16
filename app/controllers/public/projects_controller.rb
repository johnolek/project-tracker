module Public
  class ProjectsController < ApplicationController
    def show
      @project = Project.find_by!(public_token: params[:public_token])
    end
  end
end
