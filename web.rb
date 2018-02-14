#1
require 'sinatra'
require 'stripe'
require 'json'

#2
Stripe.api_key = ENV['STRIPE_TEST_SECRET_KEY']

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

  if payload[:customer] != 'nil'
    #we have an existing customer!
    begin
      customer = Stripe::Customer.retrieve(payload[:customer])
      charge = Stripe::Charge.create(
        :amount => payload[:amount], # $15.00 this time
        :currency => payload[:currency],
        :customer => customer_id, # Previously stored, then retrieved
      )
      rescue Stripe::StripeError => e
      status 402
      return "Error creating charge: #{e.message}"
    end
  else
    begin
    # Create a Customer:
      customer = Stripe::Customer.create(
        :email => "paying.user@example.com",
        :source => token,
      )
      #write stripe customer to firebase!!!!!!!!

      charge = Stripe::Charge.create(
        :amount => payload[:amount],
        :currency => payload[:currency],
        :source => payload[:token],
        :description => payload[:description]
      )

      rescue Stripe::StripeError => e
      status 402
      return "Error creating charge: #{e.message}"
    end
  end

  status 200
  return "Charge successfully created"
end
