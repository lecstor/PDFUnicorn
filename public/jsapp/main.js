requirejs.config({
    deps: ["jquery","bootstrap"],
    paths: {
        "jquery": [
            "https://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min",
            // If the CDN fails, load from this local module instead
            "/lib/jquery/jquery.min"
        ],
        "stripe_checkout": "https://checkout.stripe.com/checkout",
        "bootstrap": "/lib/bootstrap/dist/js/bootstrap.min",
        "underscore": "/lib/underscore-min",
        "backbone": "/lib/backbone-min",
        "layoutmanager": "/lib/backbone.layoutmanager/backbone.layoutmanager",
        "html5shiv": "/lib/html5shiv",
        "respond": "/lib/respond.min",
        "moment": "/lib/moment.min",
        "app": "libs",
        "admin": 'libs/admin',
        "invoice": 'libs/invoice',
    },

    shim: {
        bootstrap: {
            deps: ["jquery"],
        },
        backbone: {
            deps: ["jquery", "underscore"],
            exports: "Backbone"
        },
        underscore: {
            exports: '_'
        },
        stripe_checkout: {
            exports: 'StripeCheckout'
        }
    }
});

var path = location.pathname;

require(['jquery'], function($){
    $('[data-toggle=offcanvas]').click(function() {
        $('.row-offcanvas').toggleClass('active');
    });
});

require(['bootstrap'], function(){
    $('[data-toggle=tooltip]').tooltip();
});

var re = new RegExp("^/admin/");
if (re.test(path)){

    require(['backbone','admin/session'], function(Backbone, Session){

        var openSignin = function(resp, options){
            console.log(resp);

            var signin_form = new Session.View({
                el: '#signinModal',
                model: new Session.Model()
            });

            if (resp.status == 401){
                $('#signinModal').modal();
            } else {
                options.error && options.error(resp);
            }
        };

        var bbSync = Backbone.sync;
        Backbone.sync = function(method, model, options){
            options || (options = {});
            var error = options.error;
            options.error = function(resp){
                openSignin(resp, { error: error });
            };
            return bbSync(method, model, options);
        };

    });

}

if (path == '/admin/api-key'){

    require(['admin/apikeys'], function(apiKeys){
        apiKeys.table.setElement($('#api-keys-table'));
        apiKeys.table.render();
    });

} else if(path == '/admin/billing') {

    require(['jquery', 'admin/stripe'], function($, stripe){
        //stripe.payment_details.public_api_key = $('#stripe-public_api_key').text();
        //stripe.payment_details['public_api_key'] = $('#stripe-public_api_key').text();
        stripe.customer_model.fetch({
            success: function(){
                stripe.subscription.setElement($('#stripe-subscription'));
                stripe.subscription.render();

                stripe.payment_details.setElement($('#stripe-payment_details'));
                stripe.payment_details.render();
            }
        });

    });

} else if (path == '/invoice-maker'){

    require(['invoice/maker']);

} else if (path == '/admin/stripe/connect'){

    require(['jquery', 'admin/stripe_connect/customer', 'admin/stripe_connect/invoices', 'admin/templates'], function($, customer, invoices, Template){
        var customerView = new customer.view.customer({ el: '#customer-view' });
        var lookup = new customer.view.lookup({
            el: '#customer-lookup',
            customerView: new customer.view.customer()
        });

        $('#customer a').click(function (e) {
            e.preventDefault();
            $(this).tab('customer');
        });

        $('#template a').click(function (e) {
            e.preventDefault();
            $(this).tab('template');
        });

        //var template_list = new templates.ListView({
        //    el: '#template-list',
        //    collection: new templates.Collection()
        //});

        var templates = new Template.Collection();
        templates.fetch({
            success: function(collection, response, options){
                //collection.add(new Template.Model({ name: 'New Template' }));
                var template_editor_layout = new Template.EditorLayout({
                    el: '#template-editor-layout',
                    collection: collection,
                    model: collection.first()
                });
                template_editor_layout.render();
            }
        });

        // template_editor_layout.fetch_templates({
            // success: function(collection, response, options){
                // template_editor_layout.set_model()
                // template_editor_layout.render();
            // }
        // });


    });

// [Object]
//   0: Object
//     error: Object
//       message: "Expired API key provided: sk_test_************************.  Application access may have been revoked."
//       type: "invalid_request_error"

}



