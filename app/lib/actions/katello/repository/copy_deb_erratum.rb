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
          param :include_errata_ids
          param :exclude_errata_ids
        end

        def run
          target_repo = ::Katello::Repository.find(input[:target_repo_id])
          src_repo = ::Katello::Repository.find(input[:source_repo_id]) if input[:source_repo_id].present?

          # drop all existing errata from target_repo (e.g. promoting LCENV back to an earlier version)
          target_repo.repository_errata.destroy_all if input[:clean_target_errata]

          include_ids, exclude_ids = effective_policy_ids(src_repo, target_repo)

          ids_to_copy =
            if src_repo
              ids = candidate_ids(src_repo, include_ids, exclude_ids)
              ids = apply_solvability(ids, src_repo, target_repo) if input[:filtered_content]
              ids
            elsif input[:erratum_ids].present?
              ::Katello::Erratum.where(errata_id: input[:erratum_ids]).pluck(:id)
            else
              []
            end

          ids_to_copy -= target_repo.erratum_ids
          target_repo.erratum_ids |= ids_to_copy
          target_repo.save

          output[:copied_errata] = ids_to_copy.length

          # fake output to make foreman task presenter happy
          if input[:erratum_ids].present?
            units = []
            ::Katello::Erratum.find(ids_to_copy).each do |erratum|
              units << { 'type_id' => 'erratum', 'unit_key' => { 'id' => erratum.pulp_id } }
              erratum.deb_packages.map do |pkg|
                units << { 'type_id' => 'deb', 'unit_key' => { 'name' => pkg.name, 'version' => pkg.version } }
              end
            end
            output[:pulp_tasks] = [{ :result => { :units_successful => units } }]
          end
        end

        private

        def effective_policy_ids(src_repo, target_repo)
          include_ids = input[:include_errata_ids]
          exclude_ids = input[:exclude_errata_ids]

          if src_repo && target_repo && include_ids.blank? && exclude_ids.blank?
            content_view = resolve_content_view_for_repo(target_repo)
            if content_view
              filters = errata_filters_for_cv(content_view)
              inc, exc = errata_ids_from_cv_errata_filters(filters, src_repo)
              include_ids = inc if inc.present?
              exclude_ids = exc if exc.present?
            end
          end

          [include_ids, exclude_ids]
        end

        def candidate_ids(src_repo, include_ids, exclude_ids)
          ids = src_repo.erratum_ids.dup
          ids &= src_repo.errata.where(errata_id: include_ids).pluck(:id) if include_ids.present?
          ids -= src_repo.errata.where(errata_id: exclude_ids).pluck(:id) if exclude_ids.present?
          ids
        end

        def apply_solvability(ids, src_repo, dst_repo)
          solvable_ids = filter_errata_for_target_repo(src_repo, dst_repo)
          ids & solvable_ids
        end

        def resolve_content_view_for_repo(repo)
          cvr = ::Katello::ContentViewRepository.where(repository_id: repo.id).first
          return cvr.content_view if cvr&.content_view

          cvv = repo.try(:content_view_version) || repo.try(:root)&.try(:content_view_version)
          cvv&.content_view
        end

        def errata_filters_for_cv(content_view)
          return [] unless content_view
          ::Katello::ContentViewErratumFilter.where(content_view_id: content_view.id)
        end

        def errata_ids_from_cv_errata_filters(errata_filters, source_repo)
          return [[], []] if errata_filters.blank?

          included = []
          excluded = []

          errata_filters.each do |f|
            ids =
              if f.respond_to?(:filter_by_id?) && f.filter_by_id?
                f.erratum_rules.map(&:errata_id).compact
              else
                clause = f.generate_clauses(nil)
                next unless clause
                # only errata that actually exist in the source repo
                source_repo.errata.where(clause).pluck(:errata_id)
              end
            if f.inclusion?
              included |= ids
            else
              excluded |= ids
            end
          end
          [included, excluded]
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
