require(["layoutmanager"], function(Layout) {
    // Configure globally.
    Layout.configure({ manage: true });

    var view = new Backbone.View({ template: "#view" });

    var DeactiveButton = Backbone.Layout.extend({
        template: "#deactivate-apikey-button",
        events: { click: 'clicked' },
        clicked: function(){
            this.model.save({'active': false});
            this.trigger('swap');
        }
    });

    var ReactiveButton = Backbone.Layout.extend({
        template: "#reactivate-apikey-button",
        events: { click: 'clicked' },
        clicked: function(){
            this.model.save({'active': true});
            this.trigger('swap');
        }
    });

    var DeleteButton = Backbone.Layout.extend({
        template: "#delete-apikey-button",
        events: { click: 'clicked' },
        clicked: function(){
            this.model.destroy();
            this.trigger('swap');
        }
    });

    // TODO: an activator/deletor/model is needed for each key
    // at the moment there can be only one.

    var KeyModel = Backbone.Model.extend({
        urlRoot: '/admin/rest/apikeys',
        idAttribute: 'key'
    });

    var activator = new Backbone.Layout({
        el: $('#activate-apikey-container'),
        initialize: function(){

            this.model = new KeyModel({ key: this.$el.data('key') });

            var View = this;
            this.spare = new ReactiveButton({ model: this.model });

            var func = function(){
                var tmp = View.spare;
                View.spare = View.getView('');
                View.setView('', tmp);
                View.render();
                tmp.on('swap', func);
            };
            var defaultView = new DeactiveButton({ model: this.model })
            defaultView.on('swap', func);
            this.setView('', defaultView);
        },
    });
    activator.render();

    var deletor = new Backbone.Layout({
        el: $('#delete-apikey-container'),
        initialize: function(){
            this.model = new KeyModel({ key: this.$el.data('key') });
            var defaultView = new DeleteButton({ model: this.model })
            this.setView('', defaultView);
        },
    });
    deletor.render();

    APIKeys = {
        activator: activator,
        deletor: deletor
    };

});