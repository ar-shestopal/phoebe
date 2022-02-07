# frozen_string_literal: true

RSpec.describe Phoebe::Runner do
  it "has a version number" do
    expect(Phoebe::VERSION).not_to be nil
  end

  let(:headers) { { 'Authorization'=>'Bearer AUTHENTICATION TOKEN' } }
  let(:body) { {}.to_json }

  before do
    stub_request(:get, "https://api-fxtrade.oanda.com/v3/accounts/ACCOUNT_ID/pricing?instruments=EUR_USD,USD_CAD").
       with(headers: headers).to_return(status: 200, body: body, headers: {})
  end

  describe "#request_price" do

    it "makes request to broker" do
      response = described_class.request_price

      expect(response).not_to be_nil
    end
  end
end
