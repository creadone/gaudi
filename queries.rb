module Gaudi
  module Queries
    class << self
      
      # Вернуть список таблиц из схемы public
      def select_all_tables
        sql = <<~SQL
          select *
          from pg_tables
          where schemaname = 'public';
        SQL
      end

      # Создать таблицу для логов, куда пишут триггеры
      def create_audit_table
        sql = <<~SQL
          create schema if not exists temp;
          create table temp.gaudi_log_table
          (
              id        serial primary key,
              tablename varchar(50) not null,
              operation varchar(50) not null,
              timestamp timestamp   not null default current_timestamp,
              old_data  text,
              new_data  text
          );
        SQL
      end

      # Удалить таблицу с накопленными логами
      def drop_audit_table
        sql = <<~SQL
          drop table if exists temp.gaudi_log_table;
        SQL
      end

      # Создать триггер для операции
      def create_trigger(operation)
        sql = <<~SQL
          CREATE OR REPLACE FUNCTION gaudi_log_#{operation.downcase}() RETURNS TRIGGER AS $$
          BEGIN
            INSERT INTO temp.gaudi_log_table(tablename, operation, old_data, new_data)
            VALUES (TG_TABLE_NAME, \'#{operation.upcase}\', row_to_json(OLD), row_to_json(NEW));
            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;
        SQL
      end

      # Приаттачить триггер к таблице
      def attach_trigger_to_table(tablename:, operation:)
        sql = <<~SQL
          CREATE TRIGGER after_#{operation.downcase}
          AFTER #{operation.upcase} ON #{tablename}
          FOR EACH ROW EXECUTE PROCEDURE gaudi_log_#{operation.downcase}();
        SQL
      end

      # Снять триггер с таблицы
      def detach_triggers_from_table(tablename:, operation:)
        sql = <<~SQL
          DROP TRIGGER IF EXISTS after_#{operation.downcase} ON #{tablename};
        SQL
      end

      # Получить данные из таблицы с логами
      def fetch_audit_log
        sql = <<~SQL
          SELECT * from temp.gaudi_log_table
        SQL
      end

    end
  end
end