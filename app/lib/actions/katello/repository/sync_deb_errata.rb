module Actions
  module Katello
    module Repository
      class SyncDebErrata < Actions::EntryAction
        include ::Katello::ImportDebErrataHelper
        def plan(repo, force = false)
          plan_self(repo_id: repo.id, force_download: force)
        end

        def run
          repo = ::Katello::Repository.find(input[:repo_id]).root
          proxy = repo.http_proxy
          params = {}
          params['releases'] = repo.deb_releases.split(' ').map { |comp| comp.split('/')[0] }.join(',') if repo.deb_releases
          params['components'] = repo.deb_components.split(' ').join(',') if repo.deb_components
          params['architectures'] = repo.deb_architectures.split(' ').join(',') if repo.deb_architectures
          RestClient::Request.execute(
            method: :get,
            url: repo.deb_errata_url,
            proxy: proxy&.full_url,
            headers: {
              params: params,
              'If-None-Match' => input[:force_download] ? nil : repo.deb_errata_url_etag,
            }
          ) do |response, _request, _result, &block|
            case response.code
            when 200
              output[:etag] = response.headers[:etag] || ''
              output[:modified] = true
              output[:data] = response.body
            when 304 # not modified
              output[:modified] = false
            else
              response.return!(&block)
            end
          end
        rescue => e
          raise "Error while fetching errata information (#{e})"
        end

        def finalize
          if output[:modified]
            repo = ::Katello::Repository.find(input[:repo_id])
            erratum_list = JSON.parse(output[:data])
            # force re-attaching all errata if mirroring
            if repo.root.mirroring_policy == ::Katello::RootRepository::MIRRORING_POLICY_CONTENT
              ::Katello::RepositoryErratum.where(repository: repo).destroy_all
            end
            import_deb_errata(repo, erratum_list)
            repo.root.update(deb_errata_url_etag: output[:etag])
          end
        end

        def humanized_output
          output.dup.update(data: 'Trimmed')
        end

        def rescue_strategy
          Dynflow::Action::Rescue::Skip
        end
      end
    end
  end
end
