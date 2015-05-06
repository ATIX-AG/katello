module Katello
  class Pool < Katello::Model
    self.include_root_in_json = false

    include Glue::Candlepin::Pool
    include Glue::ElasticSearch::Pool if Katello.config.use_elasticsearch

    self.table_name = "katello_pools"

    # Some fields are are not native to the Candlepin object but are useful for searching
    attr_accessor :cp_provider_id
    alias_method :provider_id, :cp_provider_id
    alias_method :provider_id=, :cp_provider_id=
    attr_accessor :cp_id
    attr_accessor :subscription_id
    attr_accessor :amount

    validates_lengths_from_database

    DAYS_EXPIRING_SOON = 120
    DAYS_RECENTLY_EXPIRED = 30

    # ActivationKey includes the Pool's json in its own'
    def as_json(*_args)
      self.remote_data.merge(:cp_id => self.cp_id)
    end

    # If the pool_json is passed in, then candlepin is not hit again to fetch it. This is for the case where
    # prior to this call the pool was already fetched.
    def self.find_pool(cp_id, pool_json = nil)
      pool_json = Resources::Candlepin::Pool.find(cp_id) unless pool_json
      Katello::Pool.new(pool_json) unless pool_json.nil?
    end

    # Convert active, expiring_soon, and recently_expired into elasticsearch
    # filters and move implementation into ES pool module if performance becomes
    # an issue (though I doubt it will--just sayin')
    def self.active(subscriptions)
      subscriptions.select { |s| s.active }
    end

    def self.expiring_soon(subscriptions)
      subscriptions.select { |s| (s.end_date - Date.today) <= DAYS_EXPIRING_SOON }
    end

    def self.recently_expired(subscriptions)
      today_date = Date.today

      subscriptions.select do |s|
        end_date = s.end_date
        today_date >= end_date && today_date - end_date <= DAYS_RECENTLY_EXPIRED
      end
    end
  end
end
