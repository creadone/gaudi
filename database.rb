require 'pg'
require 'json'

require './logger'
require './queries'

module Gaudi
  class Database
    def initialize(db_config:, controller:)
      @db_config    = db_config
      @controller   = controller
      @user_options = @controller.user_options
      @connection   = establish_connection!
      @operations   = %w(insert update delete)
      @name         = @db_config[:name]
    end

    # Возвращает список все таблиц в public
    def tables
      sql = Queries.select_all_tables
      response = @connection.exec(sql).to_a
      tables_ary = response.map do |table_metadata|
        table_metadata['tablename']
      end
      tables_ary
    end

    # Создает таблицу и раскидывает по ним триггеры
    def install
      create_table_sql = Queries.create_audit_table
      @connection.exec(create_table_sql).to_a
      Gaudi.logger.debug("#{self.class}::#{@name.capitalize}"){ "Log table created" }

      @operations.each do |operation|
        create_trigger_sql = Queries.create_trigger(operation)
        @connection.exec(create_trigger_sql)
      end

      tables.each do |tablename|
        @operations.each do |operation|
          attached_trigger_sql = Queries.attach_trigger_to_table(
            tablename: tablename,
            operation: operation
          )
          @connection.exec(attached_trigger_sql)
        end
      end

      Gaudi.logger.debug("#{self.class}::#{@name.capitalize}"){ "Triggers attached" }
    end

    # Снимает триггеры с таблиц
    def uninstall
      tables.each do |tablename|
        @operations.each do |operation|
          detach_triggers_from_table_sql = Queries.detach_triggers_from_table(
            tablename: tablename,
            operation: operation
          )
          @connection.exec(detach_triggers_from_table_sql)
        end
      end

      Gaudi.logger.debug("#{self.class}::#{@name.capitalize}"){ "Triggers detached" }

      drop_table_sql = Queries.drop_audit_table
      @connection.exec(drop_table_sql)

      Gaudi.logger.debug("#{self.class}::#{@name.capitalize}"){ "Log table dropped" }
    end

    # Возвращает данные аудита
    def audit_log
      fetch_audit_log_sql = Queries.fetch_audit_log
      log_data = @connection.exec(fetch_audit_log_sql)
      log_ary = log_data.to_a
      log_ary.each do |row|
        row['new_data'] = JSON.parse(row['new_data']) if row['new_data']
        row['old_data'] = JSON.parse(row['old_data']) if row['old_data']
      end
      return { @name => log_ary }
    end

    private

    def establish_connection!
      PG.connect(
        dbname: @db_config[:dbname],
        host:   @db_config[:host],
        port:   @db_config[:port],
        user:   @db_config[:user],
        password: @db_config[:password]
      )
    end

  end
end