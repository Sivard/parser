module Parser
  module Imports
    module Staterooms

      def import_staterooms
        @log.info '--------------------------------'
        @log.info "Start loading actual cruises from: #{@folderIn}"
        @log.info ''

        load_config_params('load_cruises')

        @log.info '--------------------------------'
      end

      def load_cruises
        hashCruise = fill_cruises

        # каюты без круизов не имепортируются
        hashRooms = fill_staterooms(hashCruise) if hashCruise.present?

        Cabinet.transaction do
          if hashCruise.present?

            @log.info 'Starting delete old data'
            Stateroom.delete_all
            Cabinet.delete_all
            Tourist.delete_all

            if hashCruise.present? || hashRooms.present?
              @log.info 'Creating new cabinet'

              hashCruise.each do |key, value|
                newcru = Cabinet.new(value)
                hashRooms[key].each {|val| newcru.staterooms << Stateroom.new(val)} if hashRooms.has_key?(key)
                newcru.save!
              end
            end
          end
        end  #Cabinet.transaction

        delete_files(["/*.cru", "/*.roo"])
      end

      # загрузка файла круизов, которые в свободной продаже и доступны для заказа
      def fill_cruises
        hashCruise = Hash.new

        f = @transport.dir(@folderIn + "/*.cru").max {|a,b| a.attributes.mtime <=> b.attributes.mtime }
        return if f.nil?
        name = f.is_a?(String) ? f : f.name

        @log.info "Load file #{name}"
        count = 0

        begin
          @transport.file.open(name, 'r') do |f|
            while line = f.gets
              count += 1
              row = @conv.iconv(line).split(/#/)

              company = CruiseCompany.select('id').find_by_code(row[6].to_str.strip)

              if company.present?
                hashCruise[row[0].to_str.strip] = {
                  'code'        => row[0].to_str.strip,
                  'name'        => row[1].to_str.strip,
                  'destination' => row[2].to_str.strip,
                  'shipCode'    => row[3].to_str.strip,
                  'ship'        => row[3].to_str.strip,
                  'beginDate'   => row[4],
                  'duration'    => row[5],
                  'cruise_company_id'  => company.id
                }
              else
                @log.info("#{Time.now.strftime('%d.%m.%Y (%H:%M)')} Company with code #{row[6].to_str.strip} not found!")
              end
            end #File.read
          end # sftp.file.open

        rescue Exception => err
          @log.error err.message
          raise
        end


        @log.info 'Loaded ' + count.to_s + ' cruises'
        return hashCruise
      end #fill_cruises

      def fill_staterooms(hashCruise)
        @log.info '---------------------------------'
        @log.info "Start loading staterooms from : #{@folderIn}"
        @log.info ''

        hashRooms  = Hash.new

        f = @transport.dir(@folderIn + "/*.roo").max {|a,b| a.attributes.mtime <=> b.attributes.mtime }
        return if f.nil?

        name = f.is_a?(String) ? f : f.name
        count = 0
        @log.info 'Load file ' + name

        begin
          @transport.file.open(name, 'r') do |f|
            while line = f.gets

              count += 1
              row = @conv.iconv(line).split(/#/)
              key = row[9].to_str.strip
              hashRooms[key] = [] unless hashRooms.has_key?(key)

              @log.info("#{DateTime.now.strftime('%d.%m.%Y (%H:%M)')} Cruise with code #{key} not found!") unless hashCruise.has_key?(key)

              hashRooms[key].push({
                   'description'        => row[0].to_str.strip,
                   'category'           => row[1].to_str.strip,
                   'passengerCount'     => row[2].to_str.strip,
                   'price'              => ensure_nil(row[3]),
                   'tax'                => ensure_nil(row[4]),
                   'deposit'            => ensure_nil(row[5]),
                   'depositDate'        => row[6],
                   'fiscalPayment'      => ensure_nil(row[7]),
                   'fiscalPaymentDate'  => row[8],
                   'number'             => ensure_nil(row[10]),
                   'price2'             => ensure_nil(row[11]),
                   'booking'            => row[12].nil? ? '' : row[12].to_s.strip,
                  })
            end #File.read
          end   #sftp.file.open
        rescue  Exception => err
          @log.error(err.message)
          raise
        end

        @log.info 'Loaded ' + count.to_s + ' staterooms'
        return hashRooms
      end #fill_staterooms

    private
      def ensure_nil(s = '')
        s.present? ? s.squish : nil
      end
    end
  end
end
