module Actions
  module Katello
    module Repository
      class MetadataGenerate < Actions::Base
        def plan(repository, options = {})
          source_repository = options.fetch(:source_repository, nil)
          source_repository ||= repository.target_repository if repository.link?
          smart_proxy = options.fetch(:smart_proxy, SmartProxy.pulp_primary)
          matching_content = options.fetch(:matching_content, false)
          force_publication = options.fetch(:force_publication, false)
          deb_simple_publish_only = options.fetch(:deb_simple_publish_only, false)

          plan_action(Pulp3::Orchestration::Repository::GenerateMetadata,
                        repository, smart_proxy,
                        :force_publication => force_publication,
                        :deb_simple_publish_only => deb_simple_publish_only,
                        :source_repository => source_repository,
                        :matching_content => matching_content)
        end
      end
    end
  end
end
