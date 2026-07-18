class ProjectsController < ApplicationController
  before_action :require_login
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = current_organization.projects.order(:name)
  end

  def show
  end

  def new
    @project = current_organization.projects.new
  end

  def edit
  end

  def create
    @project = current_organization.projects.new(project_params)

    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted."
  end

  private

  def set_project
    @project = find_project!(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :slug)
  end
end
