require 'katello_test_helper'

class ImportDebErrataHelperTest < ActionView::TestCase
  include ApplicationHelper
  include Katello::ImportDebErrataHelper

  def setup
    @repo1 = katello_repositories(:debian_10_amd64)
    @repo2 = katello_repositories(:debian_9_amd64)
    @errata_json = File.read(File.join(::Katello::Engine.root, 'test', 'fixtures', 'files', 'debian10_errata.json'))
    @errata_raw = JSON.parse(@errata_json)
  end

  let(:erratum_package) do
    package = Katello::Deb.new(
      name: 'grunt',
      pulp_id: 'grunt-uuid',
      version: '1.0.1-8+deb10u3',
      architecture: 'all')
    package.save!
    package
  end

  #def teardown
  #  SETTINGS[:katello][:use_pulp_2_for_content_type] = nil
  #end

  ## import_deb_errata()
  test 'imports erratum' do
    @repo1.debs << erratum_package

    import_deb_errata(@repo1, @errata_raw)
    erratum = @repo1.errata.find_by(errata_id: 'DLA-3383-1')

    refute_nil erratum
    assert_equal 1, erratum.deb_packages.count
    assert_equal ['CVE-2022-1537'], erratum.cves.pluck(:cve_id)

    #import_deb_errata(@repo1, @errata_raw, only_add_applicable = true)
  end

  test 'modifies erratum' do
    import_deb_errata(@repo1, @errata_raw, false)
    refute_nil @repo1.errata.find_by(errata_id: 'DLA-3383-1')

    errata_raw_mod = JSON.parse(@errata_json)
    errata_raw_mod.first['description'] = 'foo'

    import_deb_errata(@repo1, errata_raw_mod, false)
    erratum = @repo1.errata.find_by(errata_id: 'DLA-3383-1')

    refute_nil erratum
    assert_equal 'foo', erratum.description
  end

  ## add_only_applicable_deb_erratum()
  test 'add repo to erratum if solvable by package within repo' do
    erratum = Katello::Erratum.new(errata_id: 'SomeErratum', pulp_id: 'SomeErratum')
    erratum.save!
    @repo1.debs << erratum_package

    add_only_applicable_deb_erratum(erratum, @repo1, @errata_raw.first)

    erratum.reload
    assert_includes erratum.repositories, @repo1
  end

  test 'empty package list does not add repo to erratum' do
    erratum = Katello::Erratum.new(errata_id: 'SomeErratum', pulp_id: 'SomeErratum')
    erratum.save!

    Rails.logger.expects(:warn).with("Repo #{@repo1} does not include packages to solve erratum #{erratum.errata_id}, check you are synching the latest upstream-version of the repository!")
    add_only_applicable_deb_erratum(erratum, @repo1, { 'packages': [] })

    refute_includes erratum.repositories, @repo1
  end

  test 'does not add repo to erratum if repo does not have package to solve erratum' do
    erratum = Katello::Erratum.new(errata_id: 'SomeErratum', pulp_id: 'SomeErratum')
    erratum.save!
    erratum_package.update(version: '1.0.1-8+deb10u2')
    @repo1.debs << erratum_package

    Rails.logger.expects(:warn).with("Repo #{@repo1} does not include packages to solve erratum #{erratum.errata_id}, check you are synching the latest upstream-version of the repository!")
    add_only_applicable_deb_erratum(erratum, @repo1, @errata_raw.first)

    refute_includes erratum.repositories, @repo1
  end

  test 'does not add repo to erratum if repo is missing some packages to solve erratum' do
    erratum = Katello::Erratum.new(errata_id: 'SomeErratum', pulp_id: 'SomeErratum')
    erratum.save!
    erratum_raw = @errata_raw.first.dup
    erratum_raw['packages'] << {
      'name' => 'testpackage',
      'version' => '3.0',
      'release' => 'buster',
    }

    @repo1.debs << erratum_package

    Rails.logger.expects(:warn).with("Erratum #{erratum.errata_id} not solvable by repo #{@repo1}, check you are synching the latest upstream-version of the repository!")
    add_only_applicable_deb_erratum(erratum, @repo1, erratum_raw)

    refute_includes erratum.repositories, @repo1
  end

  test 'does not add package with newer version' do
    erratum = katello_errata(:deb_1)
    package = katello_erratum_deb_packages(:testpackage_1)
    assert_includes @repo1.debs, katello_debs(:testpackage_2)
    data = {
      'packages' => [{
        'name' => 'testpackage',
        'version' => '2.0',
        'release' => 'buster',
      }],
    }

    add_only_applicable_deb_erratum(erratum, @repo1, data)

    assert_equal [package], erratum.deb_packages
  end

  test 'does not add package for not supported release' do
    # TODO: this would require us to cross-check the release with the repo-root's deb_release, which will be
    #       '<release>-security' or similar instead of <releases>. The latter being the value in packages-list
    skip('Currently solved by ErrataServer only providing packages for the concerned release!')

    erratum = Katello::Erratum.new(errata_id: 'SomeErratum', pulp_id: 'SomeErratum')
    erratum.save!
    @repo2.debs << erratum_package

    add_only_applicable_deb_erratum(erratum, @repo2, @errata_raw.first)

    erratum.reload
    refute_includes erratum.repositories, @repo2
  end

  test 'must add erratum-package if same erratum-package already in other release' do
    erratum = Katello::Erratum.new(errata_id: 'SomeErratum', pulp_id: 'SomeErratum')
    erratum.save!
    @repo1.debs << erratum_package
    # erratum-package already in erratum for @repo2's release
    @repo2.debs << erratum_package
    erratum.repositories << @repo2
    repo2_edp = Katello::ErratumDebPackage.new(
      erratum: erratum,
      name: 'grunt',
      version: '1.0.1-8+deb10u3',
      release: 'stretch'
    )
    repo2_edp.save!
    erratum.reload

    add_only_applicable_deb_erratum(erratum, @repo1, @errata_raw.first)

    erratum.reload
    assert_includes erratum.repositories, @repo1
    refute_nil erratum.deb_packages.find_by(name: 'grunt', release: 'buster')
  end
end
