module Parser
  module Imports
    module Hotels

      def import_hotels
        @log.info '--------------------------------'
        @log.info 'Start loading hotels and hotel_prices...'

        load_config_params('import_hotel_and_hotel_price')

        @log.info '--------------------------------'
      end

      def import_hotel_and_hotel_price
        f = @transport.dir(@folderIn + "/Hotels*.xml").max {|a,b| a.attributes.mtime <=> b.attributes.mtime }
        @log.info '- no file, loading holel done' and return nil if f.nil?

        name = f.is_a?(String) ? f : f.name
        @log.info "- Load file #{name}"

        data = @transport.file.open(name, 'r')
        doc = Nokogiri::XML(data)
        connect = ActiveRecord::Base.connection

        Hotel.transaction do
          Hotel.delete_all
          HotelPrice.delete_all

          doc.search('Body Hotel').map do |hotel|
            prices = []

            new_hotel = {
                          :name        => hotel['Name'].strip,
                          :code        => hotel['Id'].strip,
                          :country     => hotel.at('Country')['Descr'].strip,
                          :city        => hotel.at('City')['Descr'].strip,
                          :class_hotel => hotel.at('Class')['Descr'].strip,
                          :food        => hotel.at('Food')['Descr'].strip,
                          :food_code   => hotel.at('Food')['Code'].strip,
                          :currency    => hotel.at('Currency')['Descr'].strip,
                          :category1   => hotel.at('Category1')['Descr'].strip,
                          :category1_code => hotel.at('Category1')['Code'].strip,
                          :category2   => hotel.at('Category2')['Descr'].strip,
                          :category2_code => hotel.at('Category2')['Code'].strip,
                          :url         => hotel.at('Url').text.strip,
                          :room1       => hotel.at('Room1')['Descr'].strip,
                          :room1_code  => hotel.at('Room1')['Code'].strip,
                          :room2       => hotel.at('Room2')['Descr'].strip,
                          :room2_code  => hotel.at('Room2')['Code'].strip,
                          :room3       => hotel.at('Room3')['Descr'].strip,
                          :room3_code  => hotel.at('Room3')['Code'].strip,
                        }
            prices << load_hotel_price( hotel.css('Prices Date') )

            hotel = Hotel.new(new_hotel)
            hotel.save

            begin
              sql = "INSERT INTO hotel_prices (`hotel_id`,`category_number`, `date`, `price1`, `price2`, `price3`) VALUES #{prices.flatten.join(", ").gsub('hotel_id', hotel.id.to_s)}"
              connect.execute sql
            rescue
              @log.info "Ошибка у отеля #{hotel.name}"
            end
          end
        end

        @log.info "- Loaded #{Hotel.count} hotels and #{HotelPrice.count} holel prices"
        data.close

        delete_files(["/Hotels*.xml"])
      end

      def load_hotel_price(array)
        prices = []

        begin
          array.map do |price|
            prices.push "(hotel_id, 1, '#{price['Value']}', #{price.at('Category1')['Price1']}, #{price.at('Category1')['Price2']}, #{price.at('Category1')['Price3']})"

            if price.at('Category2').present?
              prices.push "(hotel_id, 2, '#{price['Value']}', #{price.at('Category1')['Price1']}, #{price.at('Category1')['Price2']}, #{price.at('Category1')['Price3']})"
            end
          end
        rescue
          []
        end

        return prices
      end
    end
  end
end
