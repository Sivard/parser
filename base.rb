require 'yaml'

module Parser
  class Base
    def initialize
      @transport = Parser::Transport::Base.new
      @log = Logger.new("#{Rails.root}/log/import.log") # на продакшене пишем в файл
      @log = Logger.new(STDOUT) if Rails.env.development? # на тесте пишем в консоль
      @log.level = Logger::INFO
      @log.info ''
      @log.info '################################'
      @log.info "Import start at #{Time.now.strftime('%Y-%m-%d %H:%M')}"
    end

    def start(method_name, *args)
      return false if method_name.nil?

      send(method_name, *args)
    end

    def load_config_params(method)
      @config = reload_config

      if @config['transport'] == 'sftp'
        Net::SFTP.start(@config['sftp']['host'],
                        @config['sftp']['login'],
                        password: @config['sftp']['password'],
                        port: @config['sftp']['port']) do |sftp|
          @transport = Parser::Transport::Sftp.new(sftp)
          @folderIn = @config['sftp']['folderIn']
          @folderOut = @config['sftp']['folderOut']

          send(method)
        end
      else
        @transport = Parser::Transport::Local.new
        @folderIn = @config['local']['folderIn']
        @folderOut = @config['local']['folderOut']

        send(method)
      end
    end

  private
    def reload_config
      config_file  = "#{Rails.root}/config/import.yml"
      config = nil
      if config_file and File.exists?(config_file)
        config = File.open(config_file) { |file| YAML.load(file) }
      end
      config
    end
  end
end
