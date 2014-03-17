define(["layoutmanager","underscore", "moment"], function(Layout, _, moment) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\%=(.+?)\%\}/g,
        evaluate: /\{\%(.+?)\%\}/g,
        escape: /\{\%\-(.+?)\%\}/g
    };

    var InvoiceModel = Backbone.Model.extend({
        //urlRoot: '/admin/stripe/connect/invoices',
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

    var InvoiceCollection = Backbone.Collection.extend({
        model: InvoiceModel,
        url: '/admin/stripe/connect/invoices',
    });

    var InvoicesView = Backbone.Layout.extend({
        template: "#stripe-invoices-tmpl",
        serialize: function() {
            return this.model.serialize();
        }
    });

    // var invoices = {
        // model: customer_model,
        // view: InvoicesView,
        // collection: InvoiceCollection
    // };

    return new InvoicesView({
        collection: new InvoiceCollection
    });

});
