# frozen_string_literal: true

require 'net/http'
require 'uri'
require "json"
require_relative "phoebe/version"
require "pry"

# require 'daru/view'

# Daru::View.plotting_library = :nyaplot

module Phoebe
  class Error < StandardError; end

  class Runner
    module INSTRUMENTS
      EUR_USD = "EUR_USD"
    end
    LN = 50
    SN = 20
    ACCOUNT_ID = "101-004-5769458-001"
    AUTHENTICATION_TOKEN = "2b275a0d349a2b4e39fb20385be139b9-2c87ccf512c722315932d0b6505d9936"
    BASE_URI = "https://api-fxpractice.oanda.com/v3"
    PRICES_URI = "#{BASE_URI}/accounts/#{ACCOUNT_ID}/instruments/#{INSTRUMENTS::EUR_USD}/candles?granularity=M1&count=#{LN}"
    ACCOUNTS_URI = "#{BASE_URI}/accounts"
    ORDERS_URL = "#{BASE_URI}/accounts/#{ACCOUNT_ID}/orders"
    POSITIONS_URI = "#{BASE_URI}/accounts/#{ACCOUNT_ID}/openPositions"

    def initialize
      @stop_run = false
      init
    end

    def run
      loop do
        if @stop_run
          p "Stop run...!"
          break
        end
        p "--->>> Process"
        process
        sleep(5)
      end
    end

    def init
      long_period_prices = request_prices(LN, INSTRUMENTS::EUR_USD)
      short_period_prices = long_period_prices[-SN..-1]
      current_price = long_period_prices.last

      long_mean = (long_period_prices.sum/LN)
      short_mean = (short_period_prices.sum/SN)

      # short_mean = current_price
      p "Debug #{short_mean} #{long_mean}"

      @was_bigger = short_mean > long_mean ? true : false

      p "Debug #{@was_bigger}"
    end

    def process
      long_period_prices = request_prices(LN, INSTRUMENTS::EUR_USD)
      short_period_prices = long_period_prices[-SN..-1]
      current_price = long_period_prices.last

      long_mean = (long_period_prices.sum/LN)
      short_mean = (short_period_prices.sum/SN)
      # short_mean = current_price

      if @was_bigger && short_mean < long_mean
        @was_bigger = false
        sell_signal(short_mean, long_mean, current_price)
        sell_order
        # buy_signal(short_mean, long_mean, current_price)
        # buy_order
      elsif !@was_bigger && short_mean > long_mean
        @was_bigger = true
        buy_signal(short_mean, long_mean, current_price)
        buy_order
        # sell_signal(short_mean, long_mean, current_price)
        # sell_order
      else
        p "No signal, current state: short_mean - #{short_mean.round(4)}, long_mean - #{long_mean.round(4)}, current_price - #{current_price.round(4)}"
        p "was_bigger - #{@was_bigger}"
      end

      position = latest_position
      return unless position

      p "Debug position #{position}"

      if position[:type] == "SHORT" && position[:pl] < -0.50
        p "STOP LOSS CLOSE"
        buy_signal(short_mean, long_mean, current_price)
        buy_order
      elsif position[:type] == "LONG" && position[:pl] < -0.50
        sell_signal(short_mean, long_mean, current_price)
        sell_order
      elsif position[:type] == "SHORT" && position[:pl] > 0.50
        buy_signal(short_mean, long_mean, current_price)
        buy_order
      elsif position[:type] == "LONG" && position[:pl] > 0.50
        sell_signal(short_mean, long_mean, current_price)
        sell_order
      end
    end

    def latest_position

      resp = request(POSITIONS_URI)
      return unless resp["positions"].any?

      short_units = resp["positions"].first["short"]["units"]
      long_units = resp["positions"].first["long"]["units"]

      position = if short_units.to_i.abs > 0
        {type: "SHORT", pl: resp["positions"].first["short"]["unrealizedPL"].to_f }
      else
        {type: "LONG", pl: resp["positions"].first["long"]["unrealizedPL"].to_f }
      end

      position
    end

    def request_prices(num=LN, instrument=INSTRUMENTS::EUR_USD)
      resp = request(PRICES_URI)
      prices = resp["candles"].map { |price| price["mid"]["c"].to_f }
      prices
    end

    def account_id
      resp = request(ACCOUNTS_URI)
      id = resp["accounts"].first["id"]
      id
    end

    def buy_signal(short_mean, long_mean, current_price)
      signal("BUY SIGNAL", short_mean, long_mean, current_price)
    end

    def sell_signal(short_mean, long_mean, current_price)
      signal("SELL SIGNAL", short_mean, long_mean, current_price)
    end

    def signal(signal, short_mean, long_mean, current_price)
      p "--->>> SIG: #{signal}, short_mean - #{short_mean}, long_mean - #{long_mean}, current_price - #{current_price}"
    end

    def buy_order
      body = buy_body
      post_request(body)

      puts "BUY order"
    end

    def sell_order
      body = sell_body
      post_request(body)
      puts "SELL order"
    end

    def buy_limit_stop_loss(current_price)
      body = buy_stop_loss_with_limit_body(current_price)
      post_request(body)

      puts "BUY STOP LOSS order"
    end

    def sell_limit_stop_loss(current_price)
      body = sell_stop_loss_with_limit_body(current_price)
      post_request(body)
      puts "SELL STOP LOSS order"
    end

    def buy_stop_loss_with_limit_body(current_price)
      stoploss_price = (current_price - current_price * 0.01).round(5)
      takeprofit_price = (current_price + current_price * 0.001).round(5)
      {
        "order": {
          "price": "#{current_price}",
          "stopLossOnFill": {
            "timeInForce": "GTC",
            "price": "#{stoploss_price}"
          },
          "takeProfitOnFill": {
            "price": "#{takeprofit_price}"
          },
          "timeInForce": "GTC",
          "instrument": "EUR_USD",
          "units": "2000",
          "type": "LIMIT",
          "positionFill": "DEFAULT"
        }
      }
    end

    def sell_stop_loss_with_limit_body(current_price)
      stoploss_price = (current_price + current_price * 0.01).round(5)
      takeprofit_price = (current_price - current_price * 0.001).round(5)
      {
        "order": {
          "price": "#{current_price}",
          "stopLossOnFill": {
            "timeInForce": "GTC",
            "price": "#{stoploss_price}"
          },
          "takeProfitOnFill": {
            "price": "#{takeprofit_price}"
          },
          "timeInForce": "GTC",
          "instrument": "EUR_USD",
          "units": "2000",
          "type": "LIMIT",
          "positionFill": "DEFAULT"
        }
      }
    end

    private

    def buy_body
      {
        "order": {
          "units": "2500",
          "instrument": "EUR_USD",
          "timeInForce": "FOK",
          "type": "MARKET",
          "positionFill": "DEFAULT"
        }
      }
    end

    def sell_body
      {
        "order": {
          "units": "-2500",
          "instrument": "EUR_USD",
          "timeInForce": "FOK",
          "type": "MARKET",
          "positionFill": "DEFAULT"
        }
      }
    end

    def post_request(body, url=ORDERS_URL)
      uri = URI(url)
      https = Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json', "Authorization" => "Bearer #{AUTHENTICATION_TOKEN}")
      req.body = body.to_json
      res = https.request(req)
      puts "response #{res.body}"
    rescue => e
      puts "failed #{e}"
    end

    def request(url)
      uri = URI.parse(url)
      request = Net::HTTP::Get.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{AUTHENTICATION_TOKEN}"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      JSON.parse(response.body)
    end
  end
end