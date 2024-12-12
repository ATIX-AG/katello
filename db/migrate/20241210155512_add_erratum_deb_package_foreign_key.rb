class AddErratumDebPackageForeignKey < ActiveRecord::Migration[6.1]
  def remove_duplicates
    cmd = <<-SQL
      DELETE FROM katello_erratum_deb_packages t1
        USING katello_erratum_deb_packages t2
          WHERE t1.erratum_id = t2.erratum_id
          AND COALESCE(t1.name,'') = COALESCE(t2.name,'')
          AND COALESCE(t1.version,'') = COALESCE(t2.version,'')
          AND COALESCE(t1.release,'') = COALESCE(t2.release,'')
          AND t1.id > t2.id
    SQL

    ActiveRecord::Base.connection.execute(cmd)
  end

  def change
    remove_duplicates

    add_index :katello_erratum_deb_packages, [:erratum_id, :version, :name, :release], :unique => true,
              :name => 'katello_erratum_deb_packages_eid_version_n_f_r'
    add_foreign_key :katello_erratum_deb_packages, :katello_errata,
                    :name => "katello_erratum_deb_packages_errata_id_fk", :column => :erratum_id
  end
end
