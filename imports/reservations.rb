module Parser
  module Imports
    module Reservations
      include ArrayForXml

      def import_reservations
        @log.info '--------------------------------'
        @log.info 'Start loading xml file...'

        load_config_params('load_xml')

        @log.info '--------------------------------'
      end

      def load_xml
        f = @transport.dir(@folderIn + "/Cabins*.xml").max {|a,b| a.attributes.mtime <=> b.attributes.mtime }
        @log.info '- no file xml' and return nil if f.nil?

        name = f.is_a?(String) ? f : f.name
        @log.info "- Load file #{name}"

        data = @transport.file.open(name, 'r')
        doc = Nokogiri::XML(data)

        array_pass_agency = load_agency(doc)
        array_pass_customer = load_customer(doc)
        array_pass = array_pass_agency + array_pass_customer
        @log.info "Loaded #{array_pass.count} passergers"

        if array_pass.present?
          Passenger.transaction do
            Passenger.delete_all

            array_pass.each do |pas|
              Passenger.new(pas).save
            end
          end
        end

        visas_data = load_visas(doc)
        avia_data = load_avia(doc)
        hotels_data = load_hotels(doc)
        hotel_orders_data = load_hotel_orders(doc)
        insurance_data = load_insurance(doc)
        gr_excursions_data = load_group_excursions(doc)

        #удаление ожидающих бронь экскурсий
        gr_exc_sort = (gr_excursions_data[0] + gr_excursions_data[1]).map{ |hash| hash.slice(:tour_number, :passengers) }
        unless gr_exc_sort.nil?
          ExcursionOrder.transaction do
            gr_exc_sort.each do |gr_ex|
              res = ExcursionOrder.where('tour_number = ? AND passenger_code = ?', gr_ex[:tour_number], gr_ex[:passengers]).first
              res.destroy unless res.nil?
            end
          end
        end

        ind_transfer_data = load_ind_transfer(doc)
        ind_excursions_data = load_ind_excursions(doc)
        extra_data = load_extra(doc)
        all_dop_agency = visas_data[0] + avia_data[0] + hotels_data[0] + hotel_orders_data[0] + insurance_data[0] + gr_excursions_data[0] + ind_transfer_data[0] + ind_excursions_data[0] + extra_data[0]
        all_dop_customer = visas_data[1] + avia_data[1] + hotels_data[1] + hotel_orders_data[1] + insurance_data[1] + gr_excursions_data[1] + ind_transfer_data[1] + ind_excursions_data[1] + extra_data[1]

        #Загружаем в таблицу
        @log.info "Start loading all additional services for agency #{all_dop_agency.count} count"
        unless all_dop_agency.nil?
          CabinetLog.transaction do
            CabinetLog.delete_all

            all_dop_agency.each do |dop|
              CabinetLog.new(dop).save
            end
          end
        end

        @log.info "Start loading all additional services for customer #{all_dop_customer.count} count"
        unless all_dop_customer.nil?
          CabinetLogUser.transaction do
            CabinetLogUser.delete_all

            all_dop_customer.each do |dop|
              CabinetLogUser.new(dop).save
            end
          end
        end

        data.close

        delete_files(["/Cabins*.xml"])
      end

      def load_agency(doc)
        agency_array = load_client_array(:contractor_id, doc.search('Cruises Agency Document'))

        @log.info "Loaded #{agency_array[0].count} actual cabines for agency"

        if agency_array[0].present?
          Reservation.transaction do
            Reservation.delete_all

            agency_array[0].each do |agency|
              Reservation.new(agency).can_save
            end
          end
        end

        return agency_array[1]
      end

      def load_customer(doc)
        customer_array = load_client_array(:usual_user_id, doc.search('Cruises Customer Document'))
        @log.info "Loaded #{customer_array[0].count} actual cabines for customer"

        if customer_array[0].present?
          ReservationUser.transaction do
            ReservationUser.delete_all

            customer_array[0].each do |customer|
              ReservationUser.new(customer).save
            end
          end
        end

        return customer_array[1]
      end

      def load_visas(doc)
        array_a = load_visas_array(:contractor_id, doc.search('Visas Agency Document'))
        @log.info "Loaded #{array_a.count} actual visas for agency"

        array_c = load_visas_array(:usual_user_id, doc.search('Visas Customer Document'))
        @log.info "Loaded #{array_c.count} actual visas for customer"

        return [array_a, array_c]
      end

      def load_avia(doc)
        array_a = load_avia_array(:contractor_id, doc.search('Avia Agency Document'))
        @log.info "Loaded #{array_a[0].count} actual avia for agency"

        array_c = load_avia_array(:usual_user_id, doc.search('Avia Customer Document'))
        @log.info "Loaded #{array_c[0].count} actual avia for customer"

        array_flight = array_a[1] + array_c[1]
        if array_flight.present?
          CabinetAvia.transaction do
            CabinetAvia.delete_all

            array_flight.flatten.each do |flight|
              CabinetAvia.new(flight).save
            end
          end
        end

        return [array_a[0], array_c[0]]
      end

      def load_hotels(doc)
        array_a = load_hotels_array(:contractor_id, doc.search('Hotels Agency Document'))
        @log.info "Loaded #{array_a.count} actual hotel for agency"

        array_c = load_hotels_array(:usual_user_id, doc.search('Hotels Customer Document'))
        @log.info "Loaded #{array_c.count} actual hotel for customer"

        return [array_a, array_c]
      end

      def load_hotel_orders(doc)
        array_a = load_hotel_orders_array(:contractor_id, doc.search('HotelsOrders Agency Document'))
        @log.info "Loaded #{array_a.count} actual hotel orders for agency"

        array_c = load_hotel_orders_array(:usual_user_id, doc.search('HotelsOrders Customer Document'))
        @log.info "Loaded #{array_c.count} actual hotel orders for customer"

        return [array_a, array_c]
      end

      def load_insurance(doc)
        array_a = load_insurance_array(:contractor_id, doc.search('Insurance Agency Document'))
        @log.info "Loaded #{array_a.count} actual insurance for agency"

        array_c = load_insurance_array(:usual_user_id, doc.search('Insurance Customer Document'))
        @log.info "Loaded #{array_c.count} actual insurance for customer"

        return [array_a, array_c]
      end

      def load_group_excursions(doc)
        array_a = load_group_excursions_array(:contractor_id, doc.search('GroupExcursions Agency Document'))
        @log.info "Loaded #{array_a.count} actual excursion for agency"

        array_c = load_group_excursions_array(:usual_user_id, doc.search('GroupExcursions Customer Document'))
        @log.info "Loaded #{array_c.count} actual excursion for customer"

        return [array_a, array_c]
      end

      def load_ind_transfer(doc)
        array_a = load_ind_transfer_array(:contractor_id, doc.search('IndTransfer Agency Document'))
        @log.info "Loaded #{array_a.count} actual transfer for agency"

        array_c = load_ind_transfer_array(:usual_user_id, doc.search('IndTransfer Customer Document'))
        @log.info "Loaded #{array_c.count} actual transfer for customer"

        return [array_a, array_c]
      end

      def load_ind_excursions(doc)
        array_a = load_ind_excursions_array(:contractor_id, doc.search('IndExcursions Agency Document'))
        @log.info "Loaded #{array_a.count} actual excursion for agency"

        array_c = load_ind_excursions_array(:usual_user_id, doc.search('IndExcursions Customer Document'))
        @log.info "Loaded #{array_c.count} actual excursion for customer"

        return [array_a, array_c]
      end

      def load_extra(doc)
        array_a = load_extra_array(:contractor_id, doc.search('Extra Agency Document'))
        @log.info "Loaded #{array_a.count} actual extra for agency"

        array_c = load_extra_array(:usual_user_id, doc.search('Extra Customer Document'))
        @log.info "Loaded #{array_c.count} actual extra for customer"

        return [array_a, array_c]
      end
    end
  end
end
