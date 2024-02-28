namespace :katello do
  desc "Remove orphaned and unneeded content/repos from a smart proxy.\
        Run with SMART_PROXY_ID=1 to run for a single smart proxy."
  task :delete_orphaned_content => ["dynflow:client"] do
    User.current = User.anonymous_admin
    smart_proxy_id = ENV['SMART_PROXY_ID']
    if smart_proxy_id
      proxy = SmartProxy.find(smart_proxy_id)
      check_katello_repo_integrity(proxy)
      remove_orphan(proxy)
    else
      SmartProxy.with_content.uniq.reverse_each do |smart_proxy|
        check_katello_repo_integrity(smart_proxy)
        remove_orphan(smart_proxy)
      end
    end
  end

  def check_katello_repo_integrity(proxy)
    return unless proxy.pulp_primary?
    found = 0
    Katello::Repository.find_each(batch_size: 200) do |repo|
      pulp_publication = repo.backend_service(proxy).lookup_publication(repo.publication_href)
      if pulp_publication.repository_version != repo.version_href
        puts "Repository #{repo.id}: '#{repo.publication_href}'.repository_version != '#{repo.version_href}'"
        found += 1
      end
    end
    if found
      puts "Found #{found} repositories with problematic pulp-links!"
      unless ENV['FORCE']
        puts "Aborting execution; to force starting the orphan-cleanup, set env-variable FORCE, e.g. 'FORCE=yes foreman-rake katello:delete_orphaned_content'"
        exit
      end
    end
  end

  def remove_orphan(proxy)
    ForemanTasks.async_task(Actions::Katello::OrphanCleanup::RemoveOrphans, proxy)
    puts _("Orphaned content deletion started in background (#{proxy}).")
  rescue RuntimeError => e
    Rails.logger.error "Smart proxy with ID #{proxy.id} may be down: #{e}"
    exit
  end
end
