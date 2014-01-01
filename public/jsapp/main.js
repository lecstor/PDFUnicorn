requirejs.config({
    paths: {
        "jquery": [
            "https://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min",
            // If the CDN fails, load from this local module instead
            "/lib/jquery/jquery.min"
        ],
        "bootstrap": "/lib/bootstrap/dist/js/bootstrap.min",
        "underscore": "/lib/underscore-min",
        "backbone": "/lib/backbone-min",
        "layoutmanager": "/lib/backbone.layoutmanager/backbone.layoutmanager",
        "html5shiv": "/lib/html5shiv",
        "respond": "/lib/respond.min",
        "app": "libs",
        "admin": 'libs/admin',
    },

    shim: {
        backbone: {
            deps: ["jquery", "underscore"],
            exports: "Backbone"
        },
        underscore: {
            exports: '_'
        },
    }
});

var path = location.pathname;
console.log(path);

if (path == '/admin/api-key'){
    require(['admin/apikeys'], function(apiKeys){
        apiKeys.table.setElement($('#api-keys-table'));
        apiKeys.table.render();
    });
} else if(path == '/admin/billing') {
    require(['admin/stripe'], function(stripe){
        stripe.subscription.setElement($('#stripe-subscription'));
        stripe.subscription.model.fetch({ success:
            function(){ stripe.subscription.render(); }
        });
    });
}

