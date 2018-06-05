class ErrorResponse < Rack::Response
  def initialize(body = [], status = 500, header = {})
    super({:error=>body}.to_json, status, header.merge({'Content-Type' => 'application/json'}))
  end
end 