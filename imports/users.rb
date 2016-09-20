module Parser
  module Imports
    module Users

      def import_users
        @log.info '---------------------------------'
        @log.info 'Start loading users ...'
        @log.info ''

        load_config_params('fill_user')

        @log.info '--------------------------------'
      end

      def fill_user
        hash_user  = Hash.new

        f = @transport.dir(@folderIn + "/user*.log").max {|a,b| a.attributes.mtime <=> b.attributes.mtime }
        return if f.nil?
        name = f.is_a?(String) ? f : f.name

        count = 0
        @log.info "Load file #{name}"

        begin
          @transport.file.open(name, 'r') do |f|
            while line = f.gets

              count += 1
              row = @conv.iconv(line).split(/#/)
              key = rand().to_s

              hash_user[key] = {
               'name'               => row[0].to_s.strip,
               'email'              => row[1].to_s.strip,
               'password'           => row[2].to_s.strip,
               'login'              => row[3].to_s.strip,
               'code'               => row[4].to_s.strip,
               'index'              => row[6].to_s.strip,
               'country'            => row[7].to_s.strip,
               'area'               => row[8].to_s.strip,
               'city'               => row[9].to_s.strip,
               'street'             => row[10].to_s.strip,
               'house'              => row[11].to_s.strip,
               'phone'              => row[12].to_s.strip,
               'passport_number'    => row[13].to_s.strip,
               'passport_birthday'  => row[14].to_s.strip,
               'passport_date'      => row[15].to_s.strip,
               'passport_begin'     => row[16].to_s.strip,
               'unique_number'      => row[5].to_s.strip,
              }

            end #File.read
          end  #sftp.file.open
        rescue  Exception => err
          @log.error(err.message)
          raise
        end

        @log.info "Loaded #{count} users"

        if hash_user.present?
          UsualUser.transaction do
            @log.info 'Creating new User'

            hash_user.each do |key, value|
              usual_user = UsualUser.new value
              begin
                usual_user.save!
              rescue
                @log.info "User #{value['name']} not save"
              end
            end
          end
        end

        delete_files(["/user*.log"])
      end
    end
  end
end
