module Milestones
  class PromoteService < Milestones::BaseService
<<<<<<< HEAD
    prepend EE::Milestones::PromoteService

=======
>>>>>>> 6306e797acca358c79c120e5b12c29a5ec604571
    PromoteMilestoneError = Class.new(StandardError)

    def execute(milestone)
      check_project_milestone!(milestone)

      Milestone.transaction do
        # Destroy all milestones with same title across projects
        destroy_old_milestones(milestone)

        group_milestone = clone_project_milestone(milestone)

        move_children_to_group_milestone(group_milestone)

        # Just to be safe
        unless group_milestone.valid?
          raise_error(group_milestone.errors.full_messages.to_sentence)
        end

        group_milestone
      end
    end

    private

    def milestone_ids_for_merge(group_milestone)
      # Pluck need to be used here instead of select so the array of ids
      # is persistent after old milestones gets deleted.
      @milestone_ids_for_merge ||= begin
        search_params = { title: group_milestone.title, project_ids: group_project_ids, state: 'all' }
        milestones = MilestonesFinder.new(search_params).execute
        milestones.pluck(:id)
      end
    end

    def move_children_to_group_milestone(group_milestone)
      milestone_ids_for_merge(group_milestone).in_groups_of(100) do |milestone_ids|
        update_children(group_milestone, milestone_ids)
      end
    end

    def check_project_milestone!(milestone)
      raise_error('Only project milestones can be promoted.') unless milestone.project_milestone?
    end

    def clone_project_milestone(milestone)
      params = milestone.slice(:title, :description, :start_date, :due_date, :state_event)

      create_service = CreateService.new(group, current_user, params)

      create_service.execute
    end

    def update_children(group_milestone, milestone_ids)
      issues = Issue.where(project_id: group_project_ids, milestone_id: milestone_ids)
      merge_requests = MergeRequest.where(source_project_id: group_project_ids, milestone_id: milestone_ids)

      [issues, merge_requests].each do |issuable_collection|
        issuable_collection.update_all(milestone_id: group_milestone.id)
      end
    end

    def group
      @group ||= parent.group || raise_error('Project does not belong to a group.')
    end

    def destroy_old_milestones(group_milestone)
      Milestone.where(id: milestone_ids_for_merge(group_milestone)).destroy_all
    end

    def group_project_ids
      @group_project_ids ||= group.projects.map(&:id)
    end

    def raise_error(message)
      raise PromoteMilestoneError, "Promotion failed - #{message}"
    end
  end
end
