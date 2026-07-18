module Api
  module V1
    class ProjectSerializer
      # @param project [Project]
      # @return [Hash]
      def self.render(project)
        {
          id: project.id,
          name: project.name,
          slug: project.slug,
          created_at: project.created_at,
          updated_at: project.updated_at
        }
      end
    end
  end
end
