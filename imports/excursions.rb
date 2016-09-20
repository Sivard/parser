module Parser
  module Imports
    module Excursions

      def import_excursions
        @log.info '--------------------------------'
        @log.info 'Start loading excursion and excursion_start_date...'

        load_config_params('import_excursion_and_excursion_start_date')

        @log.info '--------------------------------'
      end

      def import_excursion_and_excursion_start_date
        f = @transport.dir(@folderIn + "/Xcursions*.xml").max {|a,b| a.attributes.mtime <=> b.attributes.mtime }
        @log.info '- no file, loading excursion done' and return nil if f.nil?

        name = f.is_a?(String) ? f : f.name
        @log.info "- Load file #{name}"

        data = @transport.file.open(name, 'r')
        doc = Nokogiri::XML(data)
        #загружаем экскурсии
        array_excursion = doc.search('Body Xcursions Document').map{ |excursion|
          {
            :name      => excursion.at('Name').text.strip,
            :string_id => excursion.at('Id').text.strip,
            :comment   => excursion.at('Descr').text.strip,
            :city      => excursion.at('Place')['City'].strip,
            :country   => excursion.at('Place')['Country'].strip,
          }
        }
        #загружаем экскурсии для брони
        array_excursion_start_date = doc.search('Body CruiseXcursions Document').map{ |excursion_date|
          start_date = Date.strptime(excursion_date.at('Date').text.strip, "%m/%d/%Y")
          {
            :code         => excursion_date.at('Id').text.strip,
            :name         => excursion_date.at('Name').text.strip,
            :description  => excursion_date.at('Descr').text.gsub('"',"'").gsub("\\n", "\n").strip,
            :excursion_id => excursion_date.at('ParentId').text.strip,
            :route        => excursion_date.at('ItineraryId').text.strip,
            :currency     => excursion_date.at('Price')['Currency'].strip,
            :price        => excursion_date.at('Price')['Summ'].strip,
            :start_date   => start_date,
            :city         => excursion_date.at('Detales')['City'].strip,
            :start_time   => excursion_date.at('Detales')['Time'].strip,
            :duration     => excursion_date.at('Detales')['Duration'].strip,
            :optional     => excursion_date.at('ComissionInfo')['Option'].strip,
            :nofee        => excursion_date.at('ComissionInfo')['NoComission'].strip,
            :capacity     => excursion_date.at('Avilable').text.blank? ? '0' : excursion_date.at('Avilable').text.strip,
          }
        }

        # @log.info 'Start load in database excursion'

        Excursion.transaction do
          Excursion.delete_all
          ExcursionStartDate.delete_all

          array_excursion.each do |excursion|
            Excursion.new(excursion).can_save
          end
          array_excursion_start_date.each do |excursion_date|
            ExcursionStartDate.new(excursion_date).can_save
          end
        end

        @log.info "- Loaded #{array_excursion.count} excursions and #{array_excursion_start_date.count} excursion_start_dates"
        data.close

        delete_files(["/Xcursions*.xml"])
      end
    end
  end
end
