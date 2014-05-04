
define(["layoutmanager","underscore", "moment"], function(Layout, _, moment) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\%=(.+?)\%\}/g,
        evaluate: /\{\%(.+?)\%\}/g,
        escape: /\{\%\-(.+?)\%\}/g
    };

    var Model = Backbone.Model.extend({
        parse: function(resp){
            return resp.data ? resp.data : resp;
        },
    });

    var Collection = Backbone.Collection.extend({
        url: '/admin/rest/stripe_clients',
        parse: function(resp){
            console.log(resp);
            return resp.data ? resp.data : resp;
        },
    });

    var ConnectView = Backbone.Layout.extend({
        el: false,
        // template: "#connect-clients-tmpl",
        initialize: function(options){
            this.stripe_client_id = options.stripe_client_id;
            this.stripe_test_client_id = options.stripe_test_client_id;
            this.live_client = this.collection.find(function(client){
                if (client.get('livemode') == true) return true;
            });
            this.test_client = this.collection.find(function(client){
                if (client.get('livemode') == false) return true;
            });
        },
        afterRender: function(){
            if (this.live_client){
                this.$('#live-connect').html('<a href="#" class="btn btn-success" disabled>Connected</a>');
            } else {
                this.$('#live-connect').html('<a href="https://connect.stripe.com/oauth/authorize?response_type=code&client_id='+this.stripe_client_id+'" class="btn btn-primary">Connect Live</a>');
            }
            if (this.test_client){
                this.$('#test-connect').html('<a href="#" class="btn btn-success" disabled>Connected</a>');
            } else {
                this.$('#test-connect').html('<a href="https://connect.stripe.com/oauth/authorize?response_type=code&client_id='+this.test_stripe_client_id+'" class="btn btn-primary">Connect Test</a>');
            }
        }
    });

    var ConnectSwitchItemView = Backbone.Layout.extend({
        el: false,
        template: "#connect-switch-item-tmpl",
        serialize: function(){
            var data = this.model.toJSON();
            console.log(data);
            data['name'] = data.livemode ? 'live' : 'test';
            data['label'] = data.livemode ? 'Live' : 'Test';
            return data;
        }
    });

    var ConnectSwitchView = Backbone.Layout.extend({
        el: false,
        // template: "#connect-clients-tmpl",
        initialize: function(options){
            this.stripe_client_id = options.stripe_client_id;
            this.stripe_test_client_id = options.stripe_test_client_id;
            this.live_client = this.collection.find(function(client){
                if (client.get('livemode') == true) return true;
            });
            this.test_client = this.collection.find(function(client){
                if (client.get('livemode') == false) return true;
            });
            this.selected = this.test_client || this.live_client;
        },
        beforeRender: function(){
            if (this.test_client){
                var button = new ConnectSwitchItemView({ model: this.test_client });
                this.insertView(button);
                button.on('click', function(button){
                    this.selected = this.test_client;
                    this.getViews().each(function(but){
                        but.$el.removeClass('active');
                    }, this);
                    button.$el.addClass('active');
                    this.trigger('client-change', this.selected);
                }, this);
            }
            if (this.live_client){
                var button = new ConnectSwitchItemView({ model: this.live_client });
                this.insertView(button);
                button.on('click', function(button){
                    this.selected = this.live_client;
                    this.getViews().each(function(but){
                        but.$el.removeClass('active');
                    }, this);
                    button.$el.addClass('active');
                    this.trigger('client-change', this.selected);
                }, this);
            }
        },
        afterRender: function(){
            this.getViews().each(function(view){
                console.log(view, this.selected);
                if (view.model == this.selected) view.$el.addClass('active');
            }, this);
        }
    });

    return {
        Model: Model,
        Collection: Collection,
        ConnectView: ConnectView,
        ConnectSwitchView: ConnectSwitchView
    };

});
