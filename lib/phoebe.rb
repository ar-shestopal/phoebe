# frozen_string_literal: true

require 'net/http'
require 'uri'
require_relative "phoebe/version"

module Phoebe
  class Error < StandardError; end

  class Runner
    ACCOUNT_ID = "ACCOUNT_ID"
    AUTHENTICATION_TOKEN = "AUTHENTICATION TOKEN"
    PRICES_URI = "https://api-fxtrade.oanda.com/v3/accounts/#{ACCOUNT_ID}/pricing?instruments=EUR_USD%2CUSD_CAD"

    def self.request_price
      uri = URI.parse(PRICES_URI)
      request = Net::HTTP::Get.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{AUTHENTICATION_TOKEN}"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      # response.code
      # response.body
    end
  end
end
