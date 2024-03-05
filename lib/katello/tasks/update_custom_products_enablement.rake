namespace :katello do
  desc "Migrate organizations to SimpleContentAccess. If organization-label is specified, only that org is migrated."
  task :migrate_to_sca, [:organization] => [:environment, "dynflow:client"] do |_t, args|
    ::User.current = ::User.anonymous_admin
    migrator = Katello::Util::DefaultEnablementMigrator.new
    migrator.execute! args.organization
  end
end
