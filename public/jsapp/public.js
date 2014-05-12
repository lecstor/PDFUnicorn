requirejs.config({
    deps: ["jquery","bootstrap"],
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
    }
});

var path = location.pathname;

require(['bootstrap'], function(){
    $('[data-toggle=tooltip]').tooltip();
});

if (path == '/library'){

    require(
        [
            'jquery',
            'admin/templates'
        ],
        function($, Template){

            var lib_templates = new Template.Collection({
                url: '/rest/templates'
            });
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

} else if (path == '/invoice-maker'){

    require(['invoice/maker']);

}




