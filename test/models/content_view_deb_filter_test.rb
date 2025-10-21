require 'katello_test_helper'

module Katello
  class ContentViewDebFilterTest < ActiveSupport::TestCase
    def setup
      User.current = User.find(users(:admin).id)

      @repo = katello_repositories(:debian_10_amd64)
      @view = create(:katello_content_view, organization: @repo.product.organization)

      @deb1 = Katello::Deb.create!(name: 'one', version: '1.1', architecture: 'amd64', filename: 'one_1.1_amd64.deb', pulp_id: 'deb-one')
      @deb2 = Katello::Deb.create!(name: 'two', version: '1.2', architecture: 'arm64', filename: 'two_1.2_arm64.deb', pulp_id: 'deb-two')
      @deb3 = Katello::Deb.create!(name: 'three', version: '1.0', architecture: 'amd64', filename: 'three_1.0_amd64.deb', pulp_id: 'deb-three')
      @deb4 = Katello::Deb.create!(name: 'four', version: '2.0', architecture: 'i386', filename: 'four_2.0_i386.deb', pulp_id: 'deb-four')

      [@deb1, @deb2, @deb3, @deb4].each { |d| Katello::RepositoryDeb.create!(repository: @repo, deb: d) }
    end

    def test_query_debs
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      rule = FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "#{@deb1.name[0..1]}*")

      matched = filter.query_debs(@repo, rule)
      assert matched.length > 0

      all_applicable = filter.applicable_repos.map(&:debs).flatten.pluck(:filename)
      matched.each { |fn| assert_includes all_applicable, fn }
    end

    def test_rule_with_empty_string_arch_matched
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      rule = FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "#{@deb1.name}*", architecture: '')

      matched = filter.query_debs(@repo, rule)
      assert matched.length > 0
    end

    def test_name_filter_generates_mongodb_condition_by_filename
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "#{@deb1.name[0..1]}*")

      expected = { "filename" => { "$in" => [@deb1.filename] } }
      assert_equal expected, filter.generate_clauses(@repo)
    end

    def test_name_filter_generates_pulpcore_hrefs_by_filename
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "#{@deb1.name[0..1]}*")

      assert_equal [@deb1.pulp_id], filter.content_unit_pulp_ids(@repo)
    end

    def test_arch_filter_generates_mongodb_conditions_by_filename
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "*", architecture: @deb4.architecture)

      expected = { "filename" => { "$in" => [@deb4.filename] } }
      assert_equal expected, filter.generate_clauses(@repo)
    end

    def test_arch_filter_generates_pulpcore_hrefs
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "*", architecture: @deb4.architecture)

      assert_equal [@deb4.pulp_id], filter.content_unit_pulp_ids(@repo)
    end

    def test_version_filter_generates_mongodb_conditions_by_filename
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "*", version: '2.0')

      expected = { "filename" => { "$in" => [@deb4.filename] } }
      assert_equal expected, filter.generate_clauses(@repo)
    end

    def test_version_filter_generates_pulpcore_hrefs
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "*", version: '2.0')

      assert_equal [@deb4.pulp_id], filter.content_unit_pulp_ids(@repo)
    end

    def test_version_range_filter_generates_mongodb_conditions_by_filename
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "*", min_version: '1.9', max_version: '2.1')

      expected = { "filename" => { "$in" => [@deb4.filename] } }
      assert_equal expected, filter.generate_clauses(@repo)
    end

    def test_version_range_filter_generates_pulpcore_hrefs
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: "*", min_version: '1.9', max_version: '2.1')

      assert_equal [@deb4.pulp_id], filter.content_unit_pulp_ids(@repo)
    end

    def test_duplicate_matches_are_deduped_and_sorted
      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view)
      # Two rules that both match @deb1
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: 'one', architecture: 'amd64')
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: 'o*',  architecture: 'amd64')

      # Should return a single href, deterministically
      expect = filter.content_unit_pulp_ids(@repo)
      assert_equal [@deb1.pulp_id], expect
    end

    # Edge case: exclusion rule matching the only package leaves nothing
    def test_exclusion_rule_removes_only_package
      # isolate repo with only one deb
      RepositoryDeb.where(repository_id: @repo.id).delete_all
      Katello::RepositoryDeb.create!(repository: @repo, deb: @deb1)

      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view, inclusion: false)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: 'one', architecture: 'amd64')

      assert_equal [], filter.content_unit_pulp_ids(@repo)
    end

    # Inclusion sanity: include rule returns the single package
    def test_inclusion_rule_keeps_only_package
      RepositoryDeb.where(repository_id: @repo.id).delete_all
      Katello::RepositoryDeb.create!(repository: @repo, deb: @deb1)

      filter = FactoryBot.create(:katello_content_view_deb_filter, content_view: @view, inclusion: true)
      FactoryBot.create(:katello_content_view_deb_filter_rule, filter: filter, name: 'one', architecture: 'amd64')

      assert_equal [@deb1.pulp_id], filter.content_unit_pulp_ids(@repo)
    end
  end
end
