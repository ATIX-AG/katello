require "pulpcore_client"

module Katello
  module Pulp3
    module Api
      class Apt < Core
        def self.copy_class
          PulpDebClient::Copy
        end

        def publication_verbatim_class
          PulpDebClient::DebVerbatimPublication
        end

        def copy_api
          PulpDebClient::DebCopyApi.new(api_client)
        end

        def publications_verbatim_api
          PulpDebClient::PublicationsVerbatimApi.new(api_client)
        end
      end
    end
  end
end
