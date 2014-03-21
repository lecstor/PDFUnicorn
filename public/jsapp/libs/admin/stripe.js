define(["layoutmanager","underscore", "moment", "stripe_checkout"], function(Layout, _, moment, StripeCheckout) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\%=(.+?)\%\}/g,
        evaluate: /\{\%(.+?)\%\}/g,
        escape: /\{\%\-(.+?)\%\}/g
    };

    var StripeModel = Backbone.Model.extend({
        urlRoot: '/admin/stripe',
        parse: function(resp){
            return resp.data ? resp.data : resp;
        },
        serialize: function(){
            var data = JSON.parse(JSON.stringify(this.toJSON())); //deepcopy..
            data.subscription.start = moment.unix(data.subscription.start).format("ddd, Do MMM YYYY, h:mm:ssa");
            data.subscription.current_period_start = moment.unix(data.subscription.current_period_start).format("ddd, Do MMM YYYY, h:mm:ssa");
            data.subscription.current_period_end = moment.unix(data.subscription.current_period_end).format("ddd, Do MMM YYYY, h:mm:ssa");
            data.subscription.trial_start = moment.unix(data.subscription.trial_start).format("ddd, Do MMM YYYY, h:mm:ssa");
            data.subscription.trial_end = moment.unix(data.subscription.trial_end).format("ddd, Do MMM YYYY [at] ha");
            if (data.default_card){
                data.default_card = _.find(data.cards.data, function(card){ return  card.id == data.default_card; });
            }
            return data;
        }
    });

    var SubscriptionView = Backbone.Layout.extend({
        template: "#stripe-subscription-tmpl",
        serialize: function() {
            return this.model.serialize();
        }
    });

    var PaymentDetailsView = Backbone.Layout.extend({
        template: "#stripe-payment_details-tmpl",
        initialize: function(){
            var View = this;
            this.handler = StripeCheckout.configure({
                key: $('#stripe-public_api_key').text(),
                image: '/img/pdfunicorn_logo_75.png',
                token: function(cardToken, args) {
                    // Use the token to the card on the customer's account.
                    console.log(args);
                    var update_model = new StripeModel();
                    update_model.save(
                        { id: 'customer', card: cardToken.id },
                        {
                            success: function(model, response, options){
                                View.model = model;
                                View.render();
                                //SubscriptionView.model = model;
                                //SubscriptionView.render();
                            },
                            error: function(model, xhr, options){ console.log('card NOT stored successfully'); }
                        }
                    );
                }
            });

        },
        serialize: function() {
            return this.model.serialize();
        },
        events: {
            'click #stripeButton': 'stripeClick'
        },
        stripeClick: function(e){
            // Open Checkout with further options
            console.log(this.model);
            var model = this.model.toJSON();
            var plan = model.subscription.plan;
            this.handler.open({
                name: "PDFUnicorn",
                panelLabel: "Subscribe to PDFUnicorn",
                billingAddress: true,
                email: model.email,
                description: plan.name + ' plan @ $' + plan.amount/100 + "/" + plan.interval,
                amount: plan.amount,
                currency: 'AUD',
            });
            e.preventDefault();
        }
    });

    var customer_model = new StripeModel({ id: 'customer' });

    var stripe = {
        customer_model: customer_model,
        subscription: new SubscriptionView({
            model: customer_model
        }),
        payment_details: new PaymentDetailsView({
            model: customer_model
        })
    };


    return stripe;

});
