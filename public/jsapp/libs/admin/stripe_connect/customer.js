define([
    "layoutmanager",
    "underscore",
    "moment",
    "admin/stripe_connect/invoices"
    ], function(Layout, _, moment, invoices) {

    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\%=(.+?)\%\}/g,
        evaluate: /\{\%(.+?)\%\}/g,
        escape: /\{\%\-(.+?)\%\}/g
    };

    var CustomerModel = Backbone.Model.extend({
        urlRoot: '/admin/stripe/connect/customers',
        parse: function(resp){
            return resp.data ? resp.data : resp;
        },
        serialize: function(){
            var data = JSON.parse(JSON.stringify(this.toJSON())); //deepcopy..
            data.created = moment.unix(data.created).format("ddd, Do MMM YYYY, h:mm:ssa");
            if (!data.description){
                data.description = 'None';
            }
            _.each(data.invoices.data, function(invoice){
                invoice.date = moment.unix(invoice.date).format("ddd, Do MMM YYYY");
                invoice.period_start = moment.unix(invoice.period_start).format("ddd, Do MMM YYYY");
                invoice.period_end = moment.unix(invoice.period_end).format("ddd, Do MMM YYYY");
                invoice.subtotal = invoice.subtotal/100;
                invoice.total = invoice.total/100;
                invoice.amount_due = invoice.amount_due/100;
                _.each(invoice.lines.data, function(line){
                    line.amount = line.amount/100;
                    line.period.start = moment.unix(line.period.start).format("ddd, Do MMM YYYY");
                    line.period.end = moment.unix(line.period.end).format("ddd, Do MMM YYYY");
                });
            });
            data.card = _.find(data.cards.data, function(card){ console.log(card.id +'=='+ data.default_card); return card.id == data.default_card });
            return data;
        }
    });

    var LookupView = Backbone.Layout.extend({
        initialize: function(options){
            //this.customerView = options.customerView;
            this.setView('#customer-view', options.customerView);
        },
        events: {
            'click button': 'lookupCustomer'
        },
        lookupCustomer: function(ev){
            console.log('lookupCustomer');
            ev.preventDefault();
            var customer_id = this.$('#customer_id').val();
            var model = new CustomerModel({ id: customer_id });
            var customerView = this.getView('#customer-view');
            customerView.model = model;

            console.log('lookupCustomer.fetch');
            model.fetch({
                data: { invoices: 1 },
                success: function(model, response, options){
                    console.log(customerView);
                    customerView.render();
                },
                error: function(model, response, options){
                    alert('There was an error retrieving the customer');
                }
            });
        }
    });

    var CustomerView = Backbone.Layout.extend({
        template: "#customer-tmpl",
        serialize: function() {
            console.log(this.model.toJSON());
            return this.model.serialize();
        }
    });

    return {
        model: { customer: CustomerModel },
        view: {
            customer: CustomerView,
            lookup: LookupView
        }
    };

});
