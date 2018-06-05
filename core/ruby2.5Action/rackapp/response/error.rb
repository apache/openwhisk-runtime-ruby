class ErrorResponse < Rack::Response
  def initialize(body = [], status = 500, header = {})
    RackHelper.log body.to_s + caller.to_json
    super({:error=>body}.to_json, status, header.merge({'Content-Type' => 'application/json'}))
  end
end 