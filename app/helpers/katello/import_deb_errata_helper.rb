module Katello
  module ImportDebErrataHelper
    # param :only_add_applicable: only import errata that are solved by the packages available in :repo
    def import_deb_errata(repo, erratum_list, only_add_applicable = true)
      erratum_list.each do |data|
        erratum = ::Katello::Erratum.find_or_create_by(errata_id: data['name'], pulp_id: data['name'])
        erratum.with_lock do
          erratum.title = data['title']
          erratum.summary = data['summary'] || ''
          erratum.description = data['description']
          erratum.issued = data['issued']
          erratum.updated = data['updated'] || data['issued']
          erratum.severity = data['severity'] || ''
          erratum.solution = data['solution'] || ''
          erratum.reboot_suggested = data['reboot_suggested'] || false
          erratum.errata_type = 'security'
          erratum.save!
          data['cves']&.each do |cve|
            erratum.cves.find_or_initialize_by(cve_id: cve)
          end
          data['dbts_bugs']&.each do |dbts_bug|
            erratum.dbts_bugs.find_or_initialize_by(bug_id: dbts_bug)
          end

          if only_add_applicable
            add_only_applicable_deb_erratum(erratum, repo, data)
          else
            erratum.repositories << repo unless erratum.repositories.include?(repo)
          end

          erratum.save!
        end
      end
    end

    def add_only_applicable_deb_erratum(erratum, repo, data)
      # Check if the synced repository satisfies this erratum's package-requests
      solution_pkgs_in_repo = []
      data['packages']&.each do |package|
        solution_deb = erratum.deb_packages.find_or_initialize_by(
          name: package['name'],
          release: package['release'],
          version: package['version']
        )
        solution_deb.save!
        solution_pkgs_in_repo << solution_deb
      end
      # get all debs from the repo that have the same name
      debs_erratum_in_repo = repo.debs.where(name: solution_pkgs_in_repo.map { |pkg| pkg.name }).distinct
      # for these package(-names) check that all have a version bigger or equal than in the Erratum
      debs_solving_erratum = repo.debs.solving_erratum_debs(solution_pkgs_in_repo)
      # make sure all package-names available in repo are also in a version that resolves the Erratum
      if debs_solving_erratum.pluck(:name).to_set == debs_erratum_in_repo.pluck(:name).to_set
        erratum.repositories << repo unless erratum.repositories.include?(repo)
      else
        Rails.logger.warn("Erratum #{erratum.errata_id} not solvable by repo #{repo}, check you are synching the latest upstream-version of the repository!")
      end
    end
  end
end
