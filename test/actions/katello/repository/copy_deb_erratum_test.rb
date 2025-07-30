require 'katello_test_helper'

module Actions::Katello::Repository
  class TestBase < ActiveSupport::TestCase
    include Dynflow::Testing
    include Support::Actions::Fixtures
    include FactoryBot::Syntax::Methods
  end

  class CopyDebErratumTest < TestBase
    let(:action_class) { ::Actions::Katello::Repository::CopyDebErratum }
    let(:action) { create_action action_class }

    let(:src_repo) { katello_repositories(:debian_10_amd64) }
    let(:dst_repo) { katello_repositories(:debian_10_amd64_duplicate) }

    context 'with filter_errata_for_target_repo()' do
      it 'keeps all errata if no changed content in new repo' do
        dst_repo.debs = src_repo.debs
        erratum_ids = action.filter_errata_for_target_repo(src_repo, dst_repo)
        assert_equal src_repo.erratum_ids, erratum_ids
      end
      it 'keeps erratum with all needed packages present' do
        dst_repo.debs = src_repo.debs
        erratum_ok = katello_errata(:deb_1)
        Katello::ErratumDebPackage.create(
          erratum: erratum_ok,
          name: 'uno',
          version: '1.0',
          filename: 'uno_1.0_amd64.deb',
          release: 'buster'
        )
        erratum_ids = action.filter_errata_for_target_repo(src_repo, dst_repo)
        assert_includes erratum_ids, erratum_ok.id
      end
      it 'drops errata if no packages present' do
        erratum_ids = action.filter_errata_for_target_repo(src_repo, dst_repo)
        assert_empty erratum_ids
      end
      it 'drops erratum with insufficient package version' do
        dst_repo.debs << katello_debs(:testpackage_1)
        erratum_ids = action.filter_errata_for_target_repo(src_repo, dst_repo)
        assert_includes erratum_ids, katello_errata(:deb_1).id
        assert_not erratum_ids.include? katello_errata(:deb_2).id
      end
      it 'drops erratum if package is missing in repo (e.g. package-filter)' do
        # 'filter out' package uno-1.1
        dst_repo.debs = src_repo.debs - [katello_debs(:one_new)]
        erratum_nok = katello_errata(:deb_1)
        # add requirement for uno-1.1 to erratum
        Katello::ErratumDebPackage.create(
          erratum: erratum_nok,
          name: 'uno',
          version: '1.1',
          filename: 'uno_1.1_amd64.deb',
          release: 'buster'
        )
        erratum_ids = action.filter_errata_for_target_repo(src_repo, dst_repo)
        assert_includes erratum_ids, katello_errata(:deb_2).id
        assert_not erratum_ids.include?(erratum_nok.id)
      end
    end
  end
end
