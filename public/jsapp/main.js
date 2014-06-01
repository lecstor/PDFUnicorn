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

} else if (path == '/admin/stripe/invoices' || path == '/admin/stripe/connect'){

    require(
        [
            'jquery',
            'admin/stripe/customer',
            'admin/stripe/clients',
            'admin/templates'
        ],
        function($, Customers, Clients, Template){

            var wireup_help = function(){
                $('a[href="#connect"]').click(function (e) {
                    e.preventDefault();
                    $('#help').collapse();
                    $('#myTabs a[href="#connect"]').tab('show');
                });
                $('a[href="#customer"]').click(function (e) {
                    e.preventDefault();
                    $('#help').collapse();
                    $('#myTabs a[href="#customer"]').tab('show');
                });
                $('a[href="#template-select"]').click(function (e) {
                    e.preventDefault();
                    $('#help').collapse();
                    $('#myTabs a[href="#template-select"]').tab('show');
                });
                $('a[href="#templates"]').click(function (e) {
                    e.preventDefault();
                    $('#help').collapse();
                    $('#myTabs a[href="#templates"]').tab('show');
                });
                $('a[href="#template-lib"]').click(function (e) {
                    e.preventDefault();
                    $('#help').collapse();
                    $('#myTabs a[href="#template-lib"]').tab('show');
                });
            };


            var clients = new Clients.Collection();
            clients.fetch({
                success: function(collection, response, options){

                    var client;

                    var connect_view = new Clients.ConnectView({
                        el: '#connect-clients',
                        collection: collection,
                        stripe_client_id: $('#stripe-client_id').text(),
                        stripe_test_client_id: $('#stripe-test_client_id').text()
                    });
                    console.log(connect_view);
                    connect_view.render();

                    var connect_switch_view = new Clients.ConnectSwitchView({
                        el: '#connect-switch',
                        collection: collection,
                    });
                    connect_switch_view.render();

                    if (collection.length){
                        if (collection.length == 1){
                            client = collection.first();
                        } else {
                            client = collection.find(function(client){
                                if (client.get('default') == true) return true;
                            });
                        }

                        if (!client){
                            // set first test client as active
                            client = collection.find(function(client){
                                if (client.get('livemode') == false) return true;
                            });
                        }

                        if (!client){
                            // set first live client as active
                            client = collection.find(function(client){
                                if (client.get('livemode') == true) return true;
                            });
                        }

                        //var customerView = new Customers.CustomerView({ el: '#customer-view' });
                        var lookup = new Customers.LookupView({
                            el: '#customer-lookup',
                            customerView: new Customers.CustomerView(),
                            client: client
                        });
                    }

                    wireup_help();

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

                            var selected;
                            if (client){
                                selected = collection.find(function(template){
                                    if (template.id == client.template_id) return true;
                                });
                                if (!selected){
                                    selected = collection.find(function(template){
                                        if (template.get('name') == 'Stripe') return true;
                                    });
                                }
                            }

                            console.log(selected);

                            var template_selector_layout = new Template.SelectorLayout({
                                el: '#template-selector-layout',
                                collection: collection,

                                // TODO: selected template should be displayed
                                model: selected
                            });
                            template_selector_layout.render();
                        }
                    });

                    var lib_templates = new Template.Collection();
                    lib_templates.fetch({
                        data: { public: 1 },
                        success: function(collection, response, options){
                            var template_library_layout = new Template.LibraryLayout({
                                el: '#template-library-layout',
                                collection: collection,
                                model: collection.first()
                            });
                            template_library_layout.render();
                        }
                    });



                }
            });


        }
    );

// [Object]
//   0: Object
//     error: Object
//       message: "Expired API key provided: sk_test_************************.  Application access may have been revoked."
//       type: "invalid_request_error"

} else if (path == '/admin'){

    require(
        [
            'jquery',
            'admin/templates'
        ],
        function($, Template){

            var wireup_help = function(){
                $('a[href="#templates"]').click(function (e) {
                    e.preventDefault();
                    $('#help').collapse();
                    $('#myTabs a[href="#templates"]').tab('show');
                });
                $('a[href="#template-lib"]').click(function (e) {
                    e.preventDefault();
                    $('#help').collapse();
                    $('#myTabs a[href="#template-lib"]').tab('show');
                });
            };

            wireup_help();

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

            var lib_templates = new Template.Collection();
            lib_templates.fetch({
                data: { public: 1 },
                success: function(collection, response, options){
                    var template_library_layout = new Template.LibraryLayout({
                        el: '#template-library-layout',
                        collection: collection,
                        model: collection.first()
                    });
                    template_library_layout.render();
                }
            });

        }
    );

// [Object]
//   0: Object
//     error: Object
//       message: "Expired API key provided: sk_test_************************.  Application access may have been revoked."
//       type: "invalid_request_error"

}



