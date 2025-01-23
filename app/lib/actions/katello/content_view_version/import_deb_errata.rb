module Actions
  module Katello
    module ContentViewVersion
      class ImportDebErrata < Actions::EntryAction
        include ::Katello::ImportDebErrataHelper
        def plan(repo, deb_errata, force = false)
          plan_self(repo_id: repo.id, deb_errata: deb_errata, force_download: force)
        end

        def run
          repo = ::Katello::Repository.find(input[:repo_id])
          erratum_list = input[:deb_errata]
          # force re-attaching all errata if mirroring
          if repo.root.mirroring_policy == ::Katello::RootRepository::MIRRORING_POLICY_CONTENT
            ::Katello::RepositoryErratum.where(repository: repo).destroy_all
          end
          import_deb_errata(repo, erratum_list, false)
        end

        def humanized_output
          output.dup.update(data: 'Trimmed')
        end

        def rescue_strategy
          Dynflow::Action::Rescue::Skip
        end
      end
    end
  end
end
