define(["layoutmanager","underscore"], function(Layout, _) {
    // Configure globally.
    Layout.configure({ manage: true });

    var DeactiveButtonView = Backbone.Layout.extend({
        template: "#deactivate-apikey-button",
        events: { 'click button': 'clicked' },
        clicked: function(){
            this.trigger('click');
        }
    });

    var ReactiveButtonView = Backbone.Layout.extend({
        template: "#reactivate-apikey-button",
        events: { 'click button': 'clicked' },
        clicked: function(){
            this.trigger('click');
        }
    });

    var DeleteButtonView = Backbone.Layout.extend({
        template: "#delete-apikey-button",
        events: { 'click button': 'clicked' },
        clicked: function(){
            console.log('hello');
            this.trigger('click');
        }
    });

    _.templateSettings = {
        interpolate: /\{\{(.+?)\}\}/g
    };

    var RowView = Backbone.Layout.extend({
        el: false,
        template: "#apikey-row-tmpl",
        beforeRender: function(){
            if (this.model.get('active')){
                var button = new DeactiveButtonView({ model: this.model });
                button.on('click', this.deactivate, this);
                this.setView('.apikey-activate', button);
            } else {
                var button = new ReactiveButtonView({ model: this.model });
                button.on('click', this.reactivate, this);
                this.setView('.apikey-activate', button);
            }
            var button = new DeleteButtonView({ model: this.model });
            button.on('click', function(){ this.trigger('key:remove', this.model) }, this);
            this.setView('.apikey-delete', button);

        },
        render: function(){
            this.$el.html(this.template(this.model.attributes));
            return this;
        },
        deactivate: function(){
            this.model.save({'active': false});
            var tmp = this.getView('.apikey-activate');
            this.setView('.apikey-activate', new ReactiveButtonView({ model: this.model }));
            tmp.remove();
            this.render();
        },
        reactivate: function(){
            this.model.save({'active': true});
            var tmp = this.getView('.apikey-activate');
            this.setView('.apikey-activate', new DeleteButtonView({ model: this.model }));
            tmp.remove();
            this.render();
        },
        // destroy: function(){
            // console.log('helo destroy');
            // this.trigger('key:remove', this.model);
        // }
    });

    var TableView = Backbone.Layout.extend({
        template: "#apikey-table-tmpl",
        initialise: function(){
            this.collection.on('reset', this.render, this);
            this.collection.on('remove', function(model){
                console.log('helo collection remove')
                this.collection.remove(model);
                this.collection.fetch();
            }, this);
        },
        beforeRender: function(){
            var view = this;
            this.collection.each(function(key){
                var row = new RowView({ model: key });
                row.on('key:remove', function(model){
                    console.log('helo collection remove');
                    //var coll = this.collection;
                    this.collection.remove(model);
                    //this.collection.fetch();
                    var collection = this.collection;
                    model.destroy({ success: function(){
                        collection.fetch({ success: function(){
                            view.render();
                        }});
                    }});
                }, this);
                this.insertView('.apikey-table-body', row);
            }, this);
        },
    });

    var KeyModel = Backbone.Model.extend({
        idAttribute: 'key',
        urlRoot: '/admin/rest/apikeys',
        parse: function(resp){
            return resp.data ? resp.data : resp;
        }
    });

    var KeysCollection = Backbone.Collection.extend({
        url: '/admin/rest/apikeys',
        model: KeyModel,
        parse: function(resp){
            return resp.data ? resp.data : resp;
        }
    });

    var apiKeys = {};

    apiKeys.table = new TableView({
        collection: new KeysCollection(PDFU.apiKeys)
    });

    console.log(apiKeys.table.collection);

    return apiKeys;

    // TODO: an activator/deletor/model is needed for each key
    // at the moment there can be only one.

    // var activator = new Backbone.Layout({
        // el: $('#activate-apikey-container'),
        // initialize: function(){
//
            // this.model = new KeyModel({ key: this.$el.data('key') });
//
            // var View = this;
            // this.spare = new ReactiveButton({ model: this.model });
//
            // var func = function(){
                // var tmp = View.spare;
                // View.spare = View.getView('');
                // View.setView('', tmp);
                // View.render();
                // tmp.on('swap', func);
            // };
            // var defaultView = new DeactiveButton({ model: this.model });
            // defaultView.on('swap', func);
            // this.setView('', defaultView);
        // },
    // });
    // activator.render();
//
    // var deletor = new Backbone.Layout({
        // el: $('#delete-apikey-container'),
        // initialize: function(){
            // this.model = new KeyModel({ key: this.$el.data('key') });
            // var defaultView = new DeleteButton({ model: this.model })
            // this.setView('', defaultView);
        // },
    // });
    // deletor.render();
//
    // APIKeys = {
        // activator: activator,
        // deletor: deletor
    // };

});