require 'katello_test_helper'

module Katello
  class PoolTest < ActiveSupport::TestCase
    def test_active
      active_pool = FactoryGirl.build(:katello_pool, :active)
      inactive_pool = FactoryGirl.build(:katello_pool, :inactive)
      all_subscriptions = [active_pool, inactive_pool]
      active_subscriptions = Pool.active(all_subscriptions)
      assert_equal active_subscriptions, all_subscriptions - [inactive_pool]
    end

    def test_expiring_soon
      not_expiring_soon = FactoryGirl.build(:katello_pool, :not_expiring_soon)
      expiring_soon_pool = FactoryGirl.build(:katello_pool, :expiring_soon)
      all_subscriptions = [not_expiring_soon, expiring_soon_pool]
      expiring_soon_subscriptions = Pool.expiring_soon(all_subscriptions)
      assert_equal expiring_soon_subscriptions, all_subscriptions - [not_expiring_soon]
    end

    def test_recently_expired
      unexpired = FactoryGirl.build(:katello_pool, :unexpired)
      recently_expired = FactoryGirl.build(:katello_pool, :recently_expired)
      all_subscriptions = [unexpired, recently_expired]
      expired_subscriptions = Pool.recently_expired(all_subscriptions)
      assert_equal expired_subscriptions, all_subscriptions - [unexpired]
    end

    def test_recently_expired_does_not_get_long_expired_subscriptions
      unexpired = FactoryGirl.build(:katello_pool, :unexpired)
      recently_expired = FactoryGirl.build(:katello_pool, :recently_expired)
      long_expired = FactoryGirl.build(:katello_pool, :long_expired)

      all_subscriptions = [unexpired, recently_expired, long_expired]
      expired_subscriptions = Pool.recently_expired(all_subscriptions)
      assert_equal expired_subscriptions, all_subscriptions - [unexpired, long_expired]
    end

    def test_find_by_organization_and_id
      Resources::Candlepin::Pool.expects(:find).returns(nil)
      Pool.any_instance.expects(:organization).returns(nil)
      assert_raises(ActiveRecord::RecordNotFound) do
        Pool.find_by_organization_and_id!(get_organization, 3)
      end
    end

    def test_systems
      active_pool = FactoryGirl.build(:katello_pool, :active)
      systems = [katello_systems(:simple_server)]
      System.expects(:all_by_pool).with(active_pool.cp_id).returns(systems)
      assert_equal active_pool.systems, systems
    end
  end
end
