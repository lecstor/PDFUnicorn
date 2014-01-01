define(["layoutmanager","underscore"], function(Layout, _) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\{(.+?)\}\}/g
    };

    var StripeModel = Backbone.Model.extend({
        urlRoot: '/admin/stripe',
        parse: function(resp){
            return resp.data ? resp.data : resp;
        }
    });

    var SubscriptionView = Backbone.Layout.extend({
        template: "#stripe-subscription-tmpl",
    });

    var customer_model = new StripeModel({ id: 'customer' });

    var stripe = {
        subscription: new SubscriptionView({
            model: customer_model
        })
    };


    return stripe;

});
