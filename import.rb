require 'logger'
require 'net/sftp'
require 'nokogiri'
require 'iconv'

module Parser
  class Import < Parser::Base
    include Parser::Imports::Excursions
    include Parser::Imports::Hotels
    include Parser::Imports::Reservations
    include Parser::Imports::Staterooms
    include Parser::Imports::Users

    def initialize
      super
      @conv = Iconv.new("UTF-8","CP1251")
    end

    def fill_data
      self.import_staterooms
      self.import_users
      self.delay.import_excursions
      self.delay.import_hotels
      self.delay.import_reservations
    end

    def delete_files(file_names)
      @log.info '--------------------------------'
      @log.info "Deleting files... #{file_names}"
      @log.info ''

      file_names.each do |name|
        @transport.dir(@folderIn + name).each do |x|
          begin
            fl = (x.respond_to?(:name) ? x.name : x)
            unless @transport.file.directory?(fl)
              if Rails.env.production?
                @log.info("Deleting file #{fl}") if @transport.remove(fl)
              end
            end
          rescue
            @log.info 'Not deleted file ' + fl
          end
        end
      end
    end

    def self.fill_data
      self.new.start(:fill_data)
    end
  end
end
