require 'sinatra'
require 'stripe'
require 'dotenv'
require 'json'
require 'encrypted_cookie'

Dotenv.load
Stripe.api_key = ENV['STRIPE_TEST_SECRET_KEY']

use Rack::Session::EncryptedCookie,
:secret => ENV['STRIPE_TEST_SECRET_KEY'] # Actually use something secret here!

get '/' do
    status 200
    return "Great, your backend is set up. Now you can configure the Stripe example apps to point here."
end

post '/ephemeral_keys' do
    authenticate!
    puts "making key: " + params["customer_id"]
    begin
        key = Stripe::EphemeralKey.create(
          {customer: params["customer_id"]},
          {stripe_version: params["api_version"]}
          )
          rescue Stripe::StripeError => e
          status 402
          return "Error creating ephemeral key: #{e.message}"
    end
    
    status 200
    key.to_json
end

post '/charge' do
    authenticate!
    # Get the credit card details submitted by the form
    source = params[:source]

    # Create the charge on Stripe's servers - this will charge the user's card
    begin
        #temporary charge execution until below code works
        charge = Stripe::Charge.create(
                                       :amount => params[:amount], # this number should be in cents
                                       :currency => "usd",
                                       :customer => @customer.id,
                                       destination: {
                                       amount: params[:rest_amount],
                                       account: params[:restaurant_id],
                                       },
                                       :source => source,
                                       :receipt_email => params[:email],
                                       :description => "PolarEats Order",
                                       :shipping => params[:shipping],
                                       )
                                       rescue Stripe::StripeError => e
                                       status 402
                                       return "Error creating charge: #{e.message}"
        end
        
#        charge = Stripe::Charge.create({
#           :amount => params[:amount], # this number should be in cents
#           :currency => "usd",
#           :customer => @customer.id,
#           :source => source,
#           :receipt_email => params[:email],
#           :description => "PolarEats Order",
#           :shipping => params[:shipping],
#        })
#
#       # Create a Transfer to the organization equal to x percent of the total:
#       transfer = Stripe::Transfer.create({
#          :amount => params[:org_amount],
#          :currency => "usd",
#          :source_transaction => params[:id],
#          :destination => params[:organization_id],
#      })
#
#
#      transfer = Stripe::Transfer.create({
#         :amount => params[:rest_amount],
#         :currency => "usd",
#         :source_transaction => params[:id],
#         :destination => params[:restaurant_id],
#      })
#       rescue Stripe::StripeError => e
#       status 402
#       return "Error creating charge: #{e.message}"
#    end

    status 200
    return "Charge successfully created"
end

def authenticate!
    # This code simulates "loading the Stripe customer for your current session".
    # Your own logic will likely look very different.
    
    if params["customer_id"] != "0"
        customer_id = params[:customer_id]
        begin
            @customer = Stripe::Customer.retrieve(customer_id)
            #rescue Stripe::InvalidRequestError
            rescue Stripe::StripeError => e
            status 401
            return "Error creating customer !!!!"
        end
    else
        begin
            @customer = Stripe::Customer.create(:description => "Nibble Customer")
            rescue Stripe::InvalidRequestError
        end
        session[:customer_id] = @customer.id
    end
    @customer
#     return @customer if @customer
#     if session.has_key?(:customer_id)
#         print "hit session!"
#         print params["customer_id"]
#         customer_id = session[:customer_id]
#         begin
#             @customer = Stripe::Customer.retrieve(customer_id)
#             #rescue Stripe::InvalidRequestError
#             rescue Stripe::StripeError => e
#             status 401
#             return "Error creating customer !!!!"
#         end
#         else
#         begin
#             @customer = Stripe::Customer.create(:description => "Nibble Customer")
#             rescue Stripe::InvalidRequestError
#         end
#         session[:customer_id] = @customer.id
#     end
    #@customer
end

# This endpoint is used by the Obj-C example app to create a charge.
post '/create_charge' do
    # Create the charge on Stripe's servers
    begin
        charge = Stripe::Charge.create(
                                       :amount => params[:amount], # this number should be in cents
                                       :currency => "usd",
                                       :source => params[:source],
                                       )
                                       
                                       rescue Stripe::StripeError => e
                                       status 402
                                       return "Error creating charge: #{e.message}"
    end
    
    status 200
    return "Charge successfully created"
end

# This endpoint responds to webhooks sent by Stripe. To use it, you'll need
# to add its URL (https://{your-app-name}.herokuapp.com/stripe-webhook)
# in the webhook settings section of the Dashboard.
# https://dashboard.stripe.com/account/webhooks
post '/stripe-webhook' do
    json = JSON.parse(request.body.read)
    
    # Retrieving the event from Stripe guarantees its authenticity
    event = Stripe::Event.retrieve(json["id"])
    source = event.data.object
    
    # For sources that require additional user action from your customer
    # (e.g. authorizing the payment with their bank), you should use webhooks
    # to create a charge after the source becomes chargeable.
    # For more information, see https://stripe.com/docs/sources#best-practices
    WEBHOOK_CHARGE_CREATION_TYPES = ['bancontact', 'giropay', 'ideal', 'sofort', 'three_d_secure']
    if event.type == 'source.chargeable' && WEBHOOK_CHARGE_CREATION_TYPES.include?(source.type)
        begin
            charge = Stripe::Charge.create(
                                           :amount => source.amount,
                                           :currency => source.currency,
                                           :source => source.id,
                                           :customer => source.metadata["customer"],
                                           )
                                           rescue Stripe::StripeError => e
                                           p "Error creating charge: #{e.message}"
                                           return
        end
        # After successfully creating a charge, you should complete your customer's
        # order and notify them that their order has been fulfilled (e.g. by sending
        # an email). When creating the source in your app, consider storing any order
        # information (e.g. order number) as metadata so that you can retrieve it
        # here and use it to complete your customer's purchase.
    end
    status 200
end

