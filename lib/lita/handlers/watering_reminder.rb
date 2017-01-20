require 'rufus-scheduler'
require 'date'

module Lita
  module Handlers
    class WateringReminder < Handler
      on :loaded, :load_on_start
      def load_on_start(_payload)
        create_schedule
      end

      route(/el que riega los ([^\s]+) en la ([^\s]+) es ([^\s]+)/i) do |response|
        add_to_waterers(response.matches[0][2], response.matches[0][0], response.matches[0][1])
        response.reply("perfecto, entonces #{response.matches[0][2]} regará cada #{response.matches[0][0]} en la #{response.matches[0][1]}")
      end

      route(/quié?e?nes riegan?/i) do |response|
        response.reply("veamos, los que tienen dia para regar son estos: #{waterers_list.join(', ')}")
      end

      route(/([^\s]+) ya no quiere regar más/i) do |response|
        remove_from_waterers(response.matches[0][0])
        response.reply("ok!")
      end

      route(/refresh/) do |response|
        refresh
      end

      def refresh
        days = [:lunes, :martes, :miercoles, :jueves, :viernes, :sabado, :domingo]
        today = days[Date.today.wday - 1]
        now = Time.now.hour < 14 ? 'mañana' : 'tarde'
        waterers_list.each do |waterer|
          waterer = JSON.parse(waterer)
          if waterer['day'] == today.to_s && waterer['moment'] == now
            user = Lita::User.find_by_mention_name(waterer['mention_name'])
            message = "Acuérdate de regar hoy"
            robot.send_message(Source.new(user: user), message)
          end
        end
      end

      def notify(list, message)
        list.shuffle.each do |luncher|
          user = Lita::User.find_by_mention_name(luncher)
          robot.send_message(Source.new(user: user), message)
        end
      end

      def add_to_waterers(mention_name, day, moment)
        data = {
          day: day,
          moment: moment,
          mention_name: mention_name
        }
        redis.sadd("waterers", data.to_json)
      end

      def remove_from_waterers(mention_name)
        waterers_list.each do |waterer|
          w = JSON.parse(waterer)
          if w['mention_name'] == mention_name
            redis.srem("waterers", waterer)
          end
        end
      end

      def waterers_list
        redis.smembers("waterers") || []
      end

      def create_schedule
        scheduler = Rufus::Scheduler.new
        scheduler.cron("0 11,21 * * 1-5") do
          refresh
        end
      end

      Lita.register_handler(self)
    end
  end
end
