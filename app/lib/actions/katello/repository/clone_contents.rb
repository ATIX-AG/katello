module Actions
  module Katello
    module Repository
      class CloneContents < Actions::Base
        include Actions::Katello::CheckMatchingContent

        def plan(source_repositories, new_repository, options)
          filters = options.fetch(:filters, nil)
          rpm_filenames = options.fetch(:rpm_filenames, nil)
          generate_metadata = options.fetch(:generate_metadata, true)
          copy_contents = options.fetch(:copy_contents, true)
          solve_dependencies = options.fetch(:solve_dependencies, false)

          sequence do
            if copy_contents
              plan_action(Pulp3::Orchestration::Repository::CopyAllUnits,
                          new_repository,
                          SmartProxy.pulp_primary,
                          source_repositories,
                          filters: filters, rpm_filenames: rpm_filenames, solve_dependencies: solve_dependencies)
            end

            matching_content = check_matching_content(new_repository, source_repositories)
            metadata_generate(source_repositories, new_repository, filters, rpm_filenames, matching_content) if generate_metadata

            index_options = {id: new_repository.id, force_index: true}
            index_options[:source_repository_id] = source_repositories.first.id if source_repositories.count == 1 && filters.empty? && rpm_filenames.nil?

            if new_repository.deb? && generate_metadata
              plan_action(Candlepin::Product::ContentUpdate,
                          owner:           new_repository.organization.label,
                          repository_id:   new_repository.id,
                          name:            new_repository.root.name,
                          type:            new_repository.root.content_type,
                          arches:          new_repository.root.format_arches,
                          label:           new_repository.root.custom_content_label,
                          content_url:     new_repository.root.custom_content_path,
                          gpg_key_url:     new_repository.yum_gpg_key_url,
                          metadata_expire: new_repository.root.metadata_expire)
            end

            plan_action(Katello::Repository::IndexContent, index_options)

            if copy_contents
              source_repositories.select(&:deb?).each do |repository|
                include_ids, exclude_ids = errata_ids_from_filters_for_repo(filters, repository)
                plan_action(Actions::Katello::Repository::CopyDebErratum,
                            source_repo_id: repository.id,
                            target_repo_id: new_repository.id,
                            clean_target_errata: true,
                            filtered_content: filters.present?,
                            include_errata_ids: include_ids.presence,
                            exclude_errata_ids: exclude_ids.presence)
              end
            end
          end
        end

        def errata_ids_from_filters_for_repo(filters, repository)
          return [[], []] if filters.blank?
          errata_filters = Array(filters).select do |f|
            f.respond_to?(:erratum_rules) && f.erratum_rules.any?
          end

          included = []
          excluded = []

          errata_filters.each do |f|
            if f.respond_to?(:filter_by_id?) && f.filter_by_id?
              ids = f.erratum_rules.map(&:errata_id).compact
            else
              clause = f.generate_clauses(nil)
              next unless clause
              ids = repository.errata.where(clause).pluck(:errata_id)
            end

            if f.inclusion?
              included |= ids
            else
              excluded |= ids
            end
          end

          [included.uniq, excluded.uniq]
        end

        def metadata_generate(source_repositories, new_repository, filters, rpm_filenames, matching_content)
          metadata_options = {}

          metadata_options[:matching_content] = matching_content

          if source_repositories.count == 1 && filters.empty? && rpm_filenames.empty?
            metadata_options[:source_repository] = source_repositories.first
          end

          plan_action(Katello::Repository::MetadataGenerate, new_repository, metadata_options)
          unless source_repositories.first.saved_checksum_type == new_repository.saved_checksum_type
            plan_self(:source_checksum_type => source_repositories.first.saved_checksum_type,
                      :target_repo_id => new_repository.id)
          end
        end

        def finalize
          repository = ::Katello::Repository.find(input[:target_repo_id])
          source_checksum_type = input[:source_checksum_type]
          repository.update!(saved_checksum_type: source_checksum_type) if (repository && source_checksum_type)
        end
      end
    end
  end
end
