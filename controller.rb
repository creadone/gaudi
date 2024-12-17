require 'yaml'
require 'json'
require 'erb'

require './logger'
require './database'

module Gaudi
  class Controller
    attr_reader :user_options

    def initialize(user_options:)
      @db_config = YAML.load_file(File.join(__dir__, 'config.yml'))
      @databases = []
      @user_options = user_options

      prepare_db_config
      initialize_databases
    end

    def call
      current_action = @user_options[:action]
      self.send current_action.to_sym
    end

    private

    def install
      @databases.each(&:install)
    end

    def report
      logs = @databases.map(&:audit_log)
      template = File.read(File.join(__dir__, 'template.erb'))
      Dir.mkdir './reports' unless Dir.exist?('./reports')
      report_path = "./reports/#{Time.now.to_i}.html"
      
      File.open(report_path, 'w') do |io|
        io << ERB.new(template).result_with_hash({data: logs})
      end
      Gaudi.logger.debug(self.class){ "Report generated to #{report_path}" }
    end

    def uninstall
      @databases.each(&:uninstall)
    end

    def prepare_db_config
      # Символизируем ключи и заполняем немспейс в хостах
      @db_config.each do |config|
        config.transform_keys!(&:to_sym)
        config[:name] = config[:name].downcase
      end

      # Оставляем только БД, переданные в параметрах
      if @user_options[:databases]
        @db_config = @db_config.select do |config|
          @user_options[:databases].include?(config[:name])
        end
      end

      Gaudi.logger.debug(self.class){ "Config applied" }
    end

    # Создаем инстансы БД
    def initialize_databases
      @db_config.each do |config|
        @databases.push Database.new(
          db_config:  config,
          controller: self
        )
      end
      Gaudi.logger.debug(self.class){ "DBs initialized" }
    end

  end
end