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
        tagName: 'ul',
        className: 'nav nav-pills nav-stacked',
        initialize: function(options){
            console.log(options);
            this.editor = options.editor;
        },
        afterRender: function(){
            var listView = this;
            this.getViews().each(function(itemView){
                itemView.on('click', function(){
                    this.editor.open_template(itemView.model);
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
        open_template: function(model){
            if (this.selected_template){
                this.selected_template.$el.removeClass('active');
            }
            this.selected_template = listTemplateView;
            listTemplateView.$el.addClass('active');
            this.$('#editor-template-name').html(listTemplateView.model.get('name'));
            this.$('#template-source').val(listTemplateView.model.get('source'));
        },
    });

    var EditorView = Backbone.Layout.extend({
        el: false,
        template: '#template-editor-tmpl',
        events:{
            'click #save-button': 'save_template'
        },
        open_template: function(model){
            this.model = model;
            this.$('#editor-template-name').html(model.get('name'));
            this.$('#template-source').val(model.get('source'));
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
            var editorView = new EditorView();
            this.insertView('#template-editor', editorView);
            var listView = new ListView({
                collection: options.collection,
                editor: editorView
            });
            this.insertView('#template-list-items', listView);
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
        EditorLayout: EditorLayout,
        ListView: ListView,
        ListItemView: ListItemView,
    };

});