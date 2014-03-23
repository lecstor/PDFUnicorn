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
                success: function(model, response, options){
                    console.log(customerView);
                    var invoicesView = customerView.getView('#customer-invoices');
                    invoicesView.customer = customer_id;
                    invoicesView.collection.fetch({
                        data: { customer: customer_id },
                        success: function(){
                            customerView.render();
                        },
                        error: function(){
                            alert("There was an error retrieving the customer's invoices");
                        }
                    });
                },
                error: function(model, response, options){
                    alert('There was an error retrieving the customer');
                }
            });
        }
    });

    var CustomerView = Backbone.Layout.extend({
        template: "#customer-tmpl",
        views: {
            "#customer-invoices": invoices,
        },
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
