module Helpers
  CATCH_STATEMENT_REGEX = /^(alter|create|drop|update) /i
  DDL_STATEMENT_REGEX  = /^(alter|create|drop) /i

  def execute(statement)
  end

  def unstub_execute
    @adapter.unstub(:execute)
  end

  def stub_adapter_without_lock
    ActiveRecord::ConnectionAdapters::Mysql2AdapterWithoutLock.stub(:new).and_return(@adapter_without_lock)
  end

  def stub_original_execute
    original_execute = @adapter_without_lock.method(:original_execute)

    @adapter_without_lock.stub(:original_execute) do |sql|
      if sql =~ CATCH_STATEMENT_REGEX
        execute(sql.squeeze(' ').strip)
      else
        original_execute.call(sql)
      end
    end
  end

  def add_lock_none(str, with_comma)
    if str =~ DDL_STATEMENT_REGEX
      "#{str}#{with_comma ? ' ,' : ''} LOCK=NONE"
    else
      str
    end
  end

  def rebuild_table
    @table_name = :testing
    @adapter.drop_table @table_name rescue nil
    @adapter.create_table @table_name do |t|
      t.column :foo, :string, :limit => 100
      t.column :bar, :string, :limit => 100
      t.column :baz, :string, :limit => 100
      t.column :bam, :string, :limit => 100, default: "test", null: false
      t.column :extra, :string, :limit => 100
      t.timestamps
    end

    @table_name = :testing2
    @adapter.drop_table @table_name rescue nil
    @adapter.create_table @table_name do |t|
    end

    @adapter.add_index :testing, :baz
    @adapter.add_index :testing, [:bar, :baz]
    @adapter.add_index :testing, :extra, name: "best_index_of_the_world2"
    @adapter.add_index :testing, [:baz, :extra], name: "best_index_of_the_world3", unique: true
  end

  def setup
    ActiveRecord::Base.establish_connection(
      adapter: :mysql2,
      reconnect: false,
      database: "mysql_online_migrations",
      username: "root",
      host: "localhost",
      encoding: "utf8",
      socket: "/tmp/mysql.sock"
    )

    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = Logger::INFO

    @adapter = ActiveRecord::Base.connection
    @adapter_without_lock = ActiveRecord::ConnectionAdapters::Mysql2AdapterWithoutLock.new(@adapter)

    rebuild_table
  end

  def set_ar_setting(value)
    ActiveRecord::Base.stub(:mysql_online_migrations).and_return(value)
  end

  def teardown
    @adapter.drop_table :testing rescue nil
    ActiveRecord::Base.primary_key_prefix_type = nil
  end
end