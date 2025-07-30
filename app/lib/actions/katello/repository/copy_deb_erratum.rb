module Actions
  module Katello
    module Repository
      class CopyDebErratum < Actions::Base
        input_format do
          param :source_repo_id
          param :target_repo_id
          param :erratum_ids
          param :clean_target_errata
          param :filtered_content
        end

        def run
          target_repo = ::Katello::Repository.find(input[:target_repo_id])

          # drop all existing errata from target_repo (e.g. promoting LCENV back to an earlier version)
          target_repo.repository_errata.destroy_all if input[:clean_target_errata] == true

          erratum_ids_to_copy = []
          if input[:source_repo_id].present?
            src_repo = ::Katello::Repository.find(input[:source_repo_id])
            erratum_ids_to_copy = if input[:filtered_content]
                                    filter_errata_for_target_repo(src_repo, target_repo)
                                  else
                                    src_repo&.erratum_ids
                                  end
          elsif input[:erratum_ids].present?
            erratum_ids_to_copy = ::Katello::Erratum.where(errata_id: input[:erratum_ids]).pluck(:id)
          end
          erratum_ids_to_copy -= target_repo.erratum_ids
          target_repo.erratum_ids |= erratum_ids_to_copy
          target_repo.save

          output[:copied_errata] = erratum_ids_to_copy.length

          # fake output to make foreman task presenter happy
          if input[:erratum_ids].present?
            units = []
            ::Katello::Erratum.find(erratum_ids_to_copy).each do |erratum|
              units << { 'type_id' => 'erratum', 'unit_key' => { 'id' => erratum.pulp_id } }
              erratum.deb_packages.map do |pkg|
                units << { 'type_id' => 'deb', 'unit_key' => { 'name' => pkg.name, 'version' => pkg.version } }
              end
            end
            output[:pulp_tasks] = [{ :result => { :units_successful => units } }]
          end
        end

        def filter_errata_for_target_repo(src_repo, dst_repo)
          erratum_ids = []
          # find debs in target-repo and only copy errata that apply in respect to
          # 1) package-name
          dst_debs = dst_repo.debs
          filtered_errata = src_repo.errata.joins(:deb_packages).where(deb_packages: { name: dst_debs.select(:name) }).distinct
          # 2) package-version (expensive!?)
          filtered_errata.each do |erratum|
            solving_debs_in_repo = dst_repo.debs.solving_erratum_debs(erratum.deb_packages)
            next if solving_debs_in_repo.empty?

            if solving_debs_in_repo.pluck(:name).to_set == src_repo.debs.where(name: erratum.deb_packages.select(:name)).pluck(:name).to_set
              erratum_ids << erratum.id
              # else:
              # Erratum cannot be fully solved by the dst_repo, so either
              # - assume only the filtered packages are installed and therefore the other packages do not matter
              # - packages concerned by the errata cannot be updated, because they are not part of the dst_repo
            end
          end
          erratum_ids
        end
      end
    end
  end
end
