module Actions
  module Katello
    module ContentView
      class RemoveRollingRepoClone < Actions::EntryAction
        def plan(content_view, repository_ids, environment_ids)
          clone_ids = []
          environments = ::Katello::KTEnvironment.where(id: environment_ids)

          environments.each do |environment|
            concurrence do
              ::Katello::Repository.where(id: repository_ids).each do |repository|
                clone_repo = content_view.get_repo_clone(environment, repository).first
                next if clone_repo.nil?

                clone_ids << clone_repo.id
                plan_action(Actions::Pulp3::Repository::DeleteDistributions, clone_repo.id, SmartProxy.pulp_primary)
              end
              plan_action(Candlepin::Environment::SetContent, content_view, environment, content_view.content_view_environment(environment))
            end
          end
          plan_self(content_view_id: content_view.id, repository_ids: clone_ids)
        end

        def run
          ::Katello::Repository.where(id: input[:repository_ids]).destroy_all
        end

        def finalize
          env_proxies = []
          ::Katello::ContentView.find(input[:content_view_id]).environments.each do |environment|
            env_proxies |= SmartProxy.unscoped.with_environment(environment)
          end
          env_proxies.each do |proxy|
            ForemanTasks.async_task(::Actions::Katello::CapsuleContent::UpdateContentCounts, proxy)
          end
        end
      end
    end
  end
end
