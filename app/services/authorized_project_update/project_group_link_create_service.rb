# frozen_string_literal: true

module AuthorizedProjectUpdate
  class ProjectGroupLinkCreateService < BaseService
    include Gitlab::Utils::StrongMemoize

    BATCH_SIZE = 1000

    def initialize(project, group)
      @project = project
      @group = group
    end

    def execute
      group.members_from_self_and_ancestors_with_effective_access_level
           .each_batch(of: BATCH_SIZE, column: :user_id) do |members|
        existing_authorizations = existing_project_authorizations(members)
        authorizations_to_create = []
        user_ids_to_delete = []

        members.each do |member|
          existing_access_level = existing_authorizations[member.user_id]

          if existing_access_level
            # User might already have access to the project unrelated to the
            # current project share
            next if existing_access_level >= member.access_level

            user_ids_to_delete << member.user_id
          end

          authorizations_to_create << { user_id: member.user_id,
                                        project_id: project.id,
                                        access_level: member.access_level }
        end

        update_authorizations(user_ids_to_delete, authorizations_to_create)
      end

      ServiceResponse.success
    end

    private

    attr_reader :project, :group

    def existing_project_authorizations(members)
      user_ids = members.map(&:user_id)

      ProjectAuthorization.where(project_id: project.id, user_id: user_ids) # rubocop: disable CodeReuse/ActiveRecord
                          .select(:user_id, :access_level)
                          .each_with_object({}) do |authorization, hash|
        hash[authorization.user_id] = authorization.access_level
      end
    end

    def update_authorizations(user_ids_to_delete, authorizations_to_create)
      ProjectAuthorization.transaction do
        if user_ids_to_delete.any?
          ProjectAuthorization.where(project_id: project.id, user_id: user_ids_to_delete) # rubocop: disable CodeReuse/ActiveRecord
                              .delete_all
        end

        if authorizations_to_create.any?
          ProjectAuthorization.insert_all(authorizations_to_create)
        end
      end
    end
  end
end
