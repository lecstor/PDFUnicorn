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
                source: '<doc size="a4"><page></page></doc>',
                modified: (new Date).getTime()
            };
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
        comparator: function(m1,m2){
            if (m1 == m2) return 0;
            return m1 > m2 ? -1 : 1;
        },
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
        el: false,
        template: "#template-list-tmpl",
        afterRender: function(){
            var listView = this;
            this.getViews().each(function(itemView){
                itemView.on('click', function(){
                    //this.editor.open_template(itemView.model);
                    this.open_template(itemView);
                }, listView);
            });
        },
        beforeRender: function(){
            var view = this;
            this.collection.each(function(template){
                var row = new ListItemView({ model: template });
                this.insertView(row);
                //row.on('click', this.trigger('click', row.model), this)
            }, this);
        },
        open_template: function(itemView){
            this.editor.open_template(itemView.model);
            if (this.selected_template){
                this.selected_template.$el.removeClass('active');
            }
            this.selected_template = itemView;
            itemView.$el.addClass('active');
        },
    });

    var EditorNameView = Backbone.View.extend({
        el: false,
        template: '#template-editor-name-tmpl',
        serialize: function(){
            return this.model.toJSON();
        }
    });

    var EditorSourceView = Backbone.View.extend({
        el: false,
        template: '#template-editor-content-source-tmpl',
        serialize: function(){
            return this.model.toJSON();
        }
    });

    var EditorDataView = Backbone.View.extend({
        el: false,
        template: '#template-editor-content-data-tmpl',
    });

    var EditorPreviewView = Backbone.View.extend({
        el: false,
        template: '#template-editor-content-preview-tmpl',
    });

    var EditorView = Backbone.Layout.extend({
        el: false,
        template: '#template-editor-tmpl',
        events:{
            'click #save-button': 'save_template'
        },
        initialize: function(options){
            this.setView('#editor-name', new EditorNameView({ model: options.model }));
            this.setView('#editor-content', new EditorSourceView({ model: options.model }));
        },
        open_template: function(model){
            this.model = model;
            this.getView('#editor-name').model = model;
            this.getView('#editor-content').model = model;
            this.render();
        },
        save_template: function(){
            if (this.model){
                this.model.set('source', this.$('#template-source').val());
                this.model.set('sample_data', this.$('#template-data').val());
                this.model.set('name', this.$('#editor-template-name').text());
                this.model.save();
            } else {
                // new template
            }
        },
    });

    var EditorLayout = Backbone.Layout.extend({
        initialize: function(options){
            var editor = new EditorView({ model: options.model });
            this.setView('#template-editor', editor);
            this.setView('#template-list', new ListView({
                editor: editor,
                model: options.model,
                collection: options.collection
            }));
        },
    });


    return {
        Model: Model,
        Collection: Collection,
        EditorLayout: EditorLayout,
        EditorView: EditorView,
        ListView: ListView,
        ListItemView: ListItemView,
    };

});