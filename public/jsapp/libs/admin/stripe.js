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
            this.handler = StripeCheckout.configure({
                key: this.public_api_key,
                image: '/square-image.png',
                token: function(token, args) {
                  // Use the token to create the charge with a server-side script.
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
                name: 'PDFUnicorn',
                "panelLabel": "Subscribe to PDFUnicorn",
                "billingAddress": true,
                email: model.email,
                description: plan.name + ' plan @ $' + plan.amount/100 + "/" + plan.interval,
                amount: plan.amount,
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
