module Actions
  module Katello
    module ContentView
      class RefreshRollingRepo < Actions::EntryAction
        def plan(repository)
          action_subject repository
          sequence do
            plan_self(repository_id: repository.id)
            plan_action(Pulp3::Repository::RefreshDistribution, repository, SmartProxy.pulp_primary)
            plan_action(Repository::IndexContent, id: repository.id, source_repository_id: repository.library_instance.id)
          end
        end

        def run
          repository = ::Katello::Repository.find(input[:repository_id])
          library_instance = repository.library_instance
          # ensure IndexContent is not skipped!
          repository.last_contents_changed = DateTime.now if repository.version_href != library_instance.version_href

          repository.version_href = library_instance.version_href
          repository.publication_href = library_instance.publication_href
          if repository.deb_using_structured_apt?
            repository.content_id = library_instance.content_id
          end
          repository.save!
        end
      end
    end
  end
end