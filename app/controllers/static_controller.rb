class StaticController < ApplicationController
  
  before_filter :setup, only: [:index, :transactions]
	
  def index
  end

  def process_payment
    #Set session token
    if params[:saveData] == "true"
      session[:current_user_token] = params[:token]
    end
    
    #set token from the session or the input data
    if session[:current_user_token].blank?
      token = params[:token]
      save_data = params[:saveData]
    else
      token = session[:current_user_token]
      save_data = true
    end

    #Send data to Spreedly for processing based on process type
    if params[:payment_type] != "priceline"
      body = spreedly_purchase(params[:token], params[:amount], save_data)
    else
      body = spreedly_deliver(params[:token], params[:amount])
    end	

    #Use the response to formulate the return json
    if body.has_key?("transaction")
      success_message  = body["transaction"]["succeeded"]
      message = body["transaction"]["message"]
      session[:current_user_name] = body["transaction"]["shipping_address"]["name"]
      if body["transaction"].has_key?("retain_on_success")
        session_cached = body["transaction"]["retain_on_success"]
      else
        session_cached = !session[:current_user_token].blank?
      end
    else
      success_message = false
      message = body["errors"][0]["message"]
      session_cached = false
    end
  #  puts success_message
    
    #if the transaction fails then reset the session data
    unless success_message
   #   puts "changing session to nil"
      session[:current_user_token] = nil
      session[:current_user_name] = nil
    end
    
    #Send back json data
    if request.xhr?
      render :json => {
      	:transaction_succeeded => success_message,
	:message => message,
	:session_cached => session_cached,
	:session_user_name => session[:current_user_name]
      }
    end
  end

  def logout
    if not session[:current_user_token].blank?
      uri = URI.parse('https://core.spreedly.com/v1/payment_methods/'+session[:current_user_token]+'redact.json')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      get_request = Net::HTTP::Put.new(uri.request_uri)
      get_request.basic_auth(ENV["SPREEDLY_ENV_KEY"], ENV["SPREEDLY_SECRET"])
      http.set_debug_output(STDOUT)
      response = http.request(get_request)
      response_data = JSON.parse response.body
#      puts JSON.parse response.body    
#      puts 'removing session token'
    end
      session[:current_user_token] = nil
      session[:current_user_name] = nil

    if request.xhr?
      render :json =>{:status => "ok"}
    end
  end

  def transactions
    uri = URI.parse('https://core.spreedly.com/v1/transactions.json?order=desc')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    get_request = Net::HTTP::Get.new(uri.request_uri, 'Content-Type' => 'application/json')
    get_request.basic_auth(ENV["SPREEDLY_ENV_KEY"], ENV["SPREEDLY_SECRET"])
    #http.set_debug_output(STDOUT)
    response = http.request(get_request)
    response_data = JSON.parse response.body
#    puts JSON.parse response.body    
    @transaction_data = Array.new(5){Array.new()}
    #transation_data has five arrays date, amount, successful?, name, payment type
    for transaction in response_data['transactions']
      if ['Purchase', 'DeliverPaymentMethod'].include? transaction['transaction_type'] 
        @transaction_data[0].push(transaction['created_at'])
        @transaction_data[1].push(transaction['amount'])
        @transaction_data[2].push(transaction['succeeded'])
        @transaction_data[3].push(transaction['payment_method']['full_name'])
        @transaction_data[4].push(transaction['transaction_type'])
      end
    end
  end

  private
  def spreedly_purchase(token, amount, retain)
    request_params = {transaction: {payment_method_token: token, amount: amount.to_i*100, currency_code: 'USD', retain_on_success: retain}}
    uri = URI.parse('https://core.spreedly.com/v1/gateways/BWSQjQLz4BUqsVjApsDl2ICsjw9/purchase.json')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    post_request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type'=>'application/json')
    post_request.basic_auth(ENV["SPREEDLY_ENV_KEY"],ENV["SPREEDLY_SECRET"])
    post_request.body = request_params.to_json
    #http.set_debug_output(STDOUT)
    response = http.request(post_request)
    #puts response.body
    body = JSON.parse response.body
    body
  end

  def spreedly_deliver(token, amount)
    request_params = {delivery: {payment_method_token: token, url: "http://priceline.com",headers: "Content-Type: application/json", body: {amount:amount, card_number:"{{credit_card_number}}"}}}
    uri = URI.parse('https://core.spreedly.com/v1/receivers/'+ENV["SPREEDLY_PRICELINE_TOKEN"]+'/deliver.json')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    post_request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type'=>'application/json')
    post_request.basic_auth(ENV["SPREEDLY_ENV_KEY"],ENV["SPREEDLY_SECRET"])
    post_request.body = request_params.to_json
    #http.set_debug_output(STDOUT)
    response = http.request(post_request)
    #puts response.body
    body = JSON.parse response.body
    body
  end
  
  def setup
    if not session[:current_user_token].blank?
  #    puts "there is a token"
      @token_present = true
    end
    
    if not session[:current_user_name].blank?
      @user_name = session[:current_user_name]
    end
  end

end
