#1
require 'sinatra'
require 'stripe'
require 'json'
require 'Firebase'

#2
Stripe.api_key = 'sk_test_FJTJJAuysB52e6To02Wd1dmD' #ENV['STRIPE_TEST_SECRET_KEY']

base_uri = 'https://nibble-c00f6.firebaseio.com'

firebase = Firebase::Client.new(base_uri)
#3
get '/' do
  status 200
  return "Nibble backend setup correctly"
end

#4
post '/charge' do
  #5
  payload = params
  if request.content_type.include? 'application/json' and params.empty?
    payload = indifferent_params(JSON.parse(request.body.read))
  end

  if payload[:customer] != '0'
    #we have an existing customer!
    begin
      customer = Stripe::Customer.retrieve(payload[:customer])
      charge = Stripe::Charge.create(
        :amount => payload[:amount],
        :currency => payload[:currency],
        :customer => customer, 
      )
      rescue Stripe::StripeError => e
      status 402
      return "Error creating charge: #{e.message}"
    end
  else
    begin
      token = params[:token]

      # Create a Customer:
      customer = Stripe::Customer.create(
        :email => params[:email],
        :source => token,
      )

      # Charge the Customer instead of the card:
      charge = Stripe::Charge.create(
        :amount => 1000,
        :currency => "usd",
        :customer => customer.id,
      )

      id = params[:userID]
      puts id
      #firebase.update({"Users/#{id}" => customer.id })
      firebase.update('Users', {
          "#{id}" => customer.id
          })

      rescue Stripe::StripeError => e
      status 402
      return "Error creating charge: #{e.message}"
    end
  end

  status 200
  return "Charge successfully created"
end
