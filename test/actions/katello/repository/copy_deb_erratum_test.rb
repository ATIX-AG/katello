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

    let(:deb1) { katello_errata(:deb_1) }
    let(:deb2) { katello_errata(:deb_2) }

    def run_with_input(overrides = {})
      base_input = {
        source_repo_id: src_repo.id,
        target_repo_id: dst_repo.id,
        clean_target_errata: true,
        filtered_content: false,
        include_errata_ids: nil,
        exclude_errata_ids: nil,
      }.merge(overrides)

      ::Katello::Repository.stubs(:find).with(src_repo.id).returns(src_repo)
      ::Katello::Repository.stubs(:find).with(dst_repo.id).returns(dst_repo)

      act = create_action(::Actions::Katello::Repository::CopyDebErratum)

      yield(act) if block_given?

      ::Katello::Erratum.stubs(:find).returns([]) if base_input[:erratum_ids].present?
      act.stubs(:input).returns(base_input)
      act.stubs(:output).returns({})

      act.run
      dst_repo.reload
      act
    end

    context 'policy include/exclude' do
      setup do
        # make sure source repo actualy has these errata
        assert_includes src_repo.erratum_ids, deb1.id
        assert_includes src_repo.erratum_ids, deb2.id
      end

      it 'copies only included errata when include list is passed' do
        run_with_input(include_errata_ids: [deb1.errata_id])
        assert_equal_arrays [deb1.id], dst_repo.erratum_ids
      end

      it 'copies everything except excluded errata when exclude list is passed' do
        run_with_input(exclude_errata_ids: [deb2.errata_id])
        assert_includes dst_repo.erratum_ids, deb1.id
        refute_includes dst_repo.erratum_ids, deb2.id
      end

      it 'applies include then exclude (exclude prunes within included set)' do
        run_with_input(include_errata_ids: [deb1.errata_id, deb2.errata_id],
                       exclude_errata_ids: [deb2.errata_id])
        assert_equal [deb1.id], dst_repo.erratum_ids
      end
    end

    context 'fallback to CV errata filters' do
      it 'derives include from CV filters when none are passed' do
        # stub cv resolution + filters -> include only deb1 by id
        run_with_input do |act|
          fake_cv = stub(id: 123)
          act.stubs(:resolve_content_view_for_repo).returns(fake_cv)

          fake_filter = stub(
            inclusion?: true,
            filter_by_id?: true,
            erratum_rules: [stub(errata_id: deb1.errata_id)]
          )
          fake_filter.stubs(:respond_to?).with(:filter_by_id?).returns(true)

          act.stubs(:errata_filters_for_cv).with(fake_cv).returns([fake_filter])
        end
        assert_equal [deb1.id], dst_repo.erratum_ids
      end
    end

    context 'solvability order (policy first, then solvability)' do
      it 'removes policy-included errata that are not fully solvable when filtered_content is true (strict intersect)' do
        ids = src_repo.erratum_ids
        id1 = deb1.id
        other_id = (ids - [id1]).first

        run_with_input(include_errata_ids: [deb1.errata_id], filtered_content: true) do |act|
          act.stubs(:filter_errata_for_target_repo).returns([other_id])
        end
        assert_empty dst_repo.erratum_ids
      end

      it 'still excludes after solvability (exclude applied regardless)' do
        solvable_ids = src_repo.erratum_ids
        run_with_input(exclude_errata_ids: [deb2.errata_id], filtered_content: true) do |act|
          act.stubs(:filter_errata_for_target_repo).returns(solvable_ids)
        end
        assert_equal [deb1.id], dst_repo.erratum_ids
      end
    end

    context 'resolve_content_view_for_repo' do
      it 'returns CV from ContentViewRepository when presen' do
        repo = stub(id: 999)
        cv = stub(:content_view)
        cvr = stub(content_view: cv)

        ::Katello::ContentViewRepository.stubs(:where).with(repository_id: repo.id).returns([cvr])

        assert_equal cv, action.send(:resolve_content_view_for_repo, repo)
      end

      it 'falls back to repo.content_view_version.conten_view no CVR exists' do
        repo = stub(id: 1000)
        cv = stub(:content_view)
        cvv = stub(content_view: cv)

        ::Katello::ContentViewRepository.stubs(:where).with(repository_id: repo.id).returns([])

        repo.stubs(:content_view_version).returns(cvv)
        repo.stubs(:root).returns(nil)

        assert_equal cv, action.send(:resolve_content_view_for_repo, repo)
      end

      it 'falls back to repo.root.content_view_version.content_view when direct CVV missing' do
        repo = stub(id: 1001)
        cv = stub(:content_view)
        cvv = stub(content_view: cv)
        root = stub(content_view_version: cvv)

        ::Katello::ContentViewRepository.stubs(:where).with(repository_id: repo.id).returns([])

        repo.stubs(:content_view_version).returns(nil)
        repo.stubs(:root).returns(root)

        assert_equal cv, action.send(:resolve_content_view_for_repo, repo)
      end

      it 'returns nil when no CV is resolvable' do
        repo = stub(id: 1002)

        ::Katello::ContentViewRepository.stubs(:where).with(repository_id: repo.id).returns([])

        repo.stubs(:content_view_version).returns(nil)
        repo.stubs(:root).returns(nil)

        assert_nil action.send(:resolve_content_view_for_repo, repo)
      end
    end

    context 'with filter_errata_for_target_repo()' do
      it 'keeps all errata if no changed content in new repo' do
        dst_repo.debs = src_repo.debs
        erratum_ids = action.send(:filter_errata_for_target_repo, src_repo, dst_repo)
        assert_equal src_repo.erratum_ids, erratum_ids
      end
      it 'keeps erratum with all needed packages present' do
        dst_repo.debs = src_repo.debs
        erratum_ok = katello_errata(:deb_1)
        Katello::ErratumDebPackage.create!(
          erratum: erratum_ok,
          name: 'uno',
          version: '1.0',
          filename: 'uno_1.0_amd64.deb',
          release: 'buster'
        )
        erratum_ids = action.send(:filter_errata_for_target_repo, src_repo, dst_repo)
        assert_includes erratum_ids, erratum_ok.id
      end
      it 'drops errata if no packages present' do
        erratum_ids = action.send(:filter_errata_for_target_repo, src_repo, dst_repo)
        assert_empty erratum_ids
      end
      it 'drops erratum with insufficient package version' do
        dst_repo.debs << katello_debs(:testpackage_1)
        erratum_ids = action.send(:filter_errata_for_target_repo, src_repo, dst_repo)
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
        erratum_ids = action.send(:filter_errata_for_target_repo, src_repo, dst_repo)
        assert_includes erratum_ids, katello_errata(:deb_2).id
        assert_not erratum_ids.include?(erratum_nok.id)
      end
    end
  end
end
