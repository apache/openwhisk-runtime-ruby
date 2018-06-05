class SuccessResponse < Rack::Response
  def initialize(body = [], status = 200, header = {})
    super body.to_json, status, header.merge({'Content-Type' => 'application/json'})
  end
end  