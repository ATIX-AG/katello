namespace :katello do
  namespace :upgrades do
    namespace '4.13' do
      desc "Cleans DebErrata from suplicate package-entries superseeding each other. Run with COMMIT=true to commit changes."
      task :clean_deb_errata_packages => ["environment", "check_ping"] do
        def commit?
          ENV['COMMIT'] == 'true' || ENV['FOREMAN_UPGRADE'] == '1'
        end

        unless commit?
          print "The following changes will not actually be performed.  Rerun with COMMIT=true to apply the changes\n"
        end

        User.current = User.anonymous_admin

        # SELECT all duplicate ErratumDebPackages per Erratum, Package-name, and OS-release
        #        with higher versions than the original one:
        table = ::Katello::ErratumDebPackage.table_name
        duplicates = ::Katello::ErratumDebPackage.joins(<<-SQL)
          INNER JOIN #{table} t2
            ON #{table}.name = t2.name
              AND #{table}.release = t2.release
              AND #{table}.erratum_id = t2.erratum_id
              AND #{table}.version != t2.version
              AND deb_version_cmp(#{table}.version, t2.version) = 1;
        SQL

        puts "Found #{duplicates.count} superfluous Debian Erratum Package entries!"

        if commit?
          destroyed = duplicates.destroy_all
          puts "Removed #{destroyed.length} duplicate entries"
        end
      end
    end
  end
end
