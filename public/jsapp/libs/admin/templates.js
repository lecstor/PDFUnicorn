define(["layoutmanager","underscore", "moment"], function(Layout, _, moment) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\%=(.+?)\%\}/g,
        evaluate: /\{\%(.+?)\%\}/g,
        escape: /\{\%\-(.+?)\%\}/g
    };

    var Model = Backbone.Model.extend({
        defaults: function(){
            return {
                name: 'Unnamed Template',
                modified: (new Date).getTime()
            }
        },
        parse: function(resp){
            return resp.data ? resp.data : resp;
        },
        serialize: function(){
            var data = JSON.parse(JSON.stringify(this.toJSON())); //deepcopy..
            data.created = moment.unix(data.created).format("ddd, Do MMM YYYY, h:mm:ssa");
            return data;
        }
    });

    var Collection = Backbone.Collection.extend({
        url: '/admin/rest/templates',
        model: Model,
        comparator: 'modified',
        parse: function(resp){
            return resp.data ? resp.data : resp;
        }
    });

    var ListItemView = Backbone.Layout.extend({
        el: false,
        template: "#template-list-item-tmpl",
        events: {
            'click a': 'clicked'
        },
        clicked: function(){
            this.trigger('click');
        }
    });

    var ListView = Backbone.Layout.extend({
        tagName: 'ul',
        className: 'nav nav-pills nav-stacked',
        //template: "#template-list-tmpl",
        beforeRender: function(){
            var view = this;
            this.collection.each(function(template){
                var row = new ListItemView({ model: template });
                this.insertView(row);
                //row.on('click', this.trigger('click', row.model), this)
            }, this);
        },
    });

    var EditorView = Backbone.Layout.extend({
        initialize: function(options){
            var listView = new ListView({ collection: options.collection });
            this.insertView('.template-list-items', listView);
        },
        events:{
            'click #save-button': 'save_template'
        },
        afterRender: function(){
            var editor = this;
            this.getView('.template-list-items').getViews().each(function(itemView){
                itemView.on('click', function(){
                    if (editor.selected_template){
                        editor.selected_template.$el.removeClass('active');
                    }
                    editor.selected_template = this;
                    this.$el.addClass('active');
                    editor.$('#editor-template-name').html(this.model.get('name'));
                    editor.$('#template-source').val(this.model.get('source'));
                }, itemView);
            });
        },
        save_template: function(){
            if (this.selected_template){
                var model = this.selected_template.model;
                model.set('source', this.$('#template-source').val());
                model.set('sample_data', this.$('#template-data').val());
                model.set('name', this.$('#editor-template-name').text());
                model.save();
            } else {
                // new template
            }
        },
        fetch_templates: function(options){
            if (!options) options = {};
            var orig_success = options.success;
            options.success = function(collection, response, options){
                collection.add(new Model({ name: 'New Template' }));
                orig_success(collection, response, options);
            };
            this.collection.fetch(options)
        }
    });

    return {
        Model: Model,
        Collection: Collection,
        EditorView: EditorView,
        ListView: ListView,
        ListItemView: ListItemView,
    };

});