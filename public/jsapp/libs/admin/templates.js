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
                source: '<doc size="a4"><page>{{some_text}}</page></doc>',
                sample_data: { "some_text": "Hello World!" },
                modified: (new Date).getTime()
            };
        },
        parse: function(resp){
            return resp.data ? resp.data : resp;
        },
        serialize: function(){
            var data = JSON.parse(JSON.stringify(this.toJSON())); //deepcopy..
            data.created = moment.unix(data.created).format("ddd, Do MMM YYYY, h:mm:ssa");
            data.modified = moment.unix(data.modified).format("ddd, Do MMM YYYY, h:mm:ssa");
            return data;
        }
    });

    var Collection = Backbone.Collection.extend({
        url: '/admin/rest/templates',
        model: Model,
        comparator: function(m1,m2){
            var d1 = m1.get('modified'),
                d2 = m2.get('modified');
            if (d1 == d2) return 0;
            return d1 > d2 ? -1 : 1;
        },
        parse: function(resp){
            return resp.data ? resp.data : resp;
        }
    });

    var ListItemView = Backbone.Layout.extend({
        el: false,
        template: "#template-list-item-tmpl",
        events: {
            'click a': 'clicked',
            'click .trash': 'remove',
            'mouseover a': 'show_options',
            'mouseout a': 'hide_options',
        },
        clicked: function(){
            this.trigger('click');
        },
        show_options: function(){
            this.$('.trash').show();
        },
        hide_options: function(){
            this.$('.trash').hide();
        },
        remove: function(event){
            console.log('remove');
            this.model.destroy({
                success: function(){
                    console.log('destryed? 222');
                }
            });
            event.preventDefault();
        }
    });

    var ListView = Backbone.Layout.extend({
        el: false,
        template: "#template-list-tmpl",
        afterRender: function(){
            var listView = this;
            var views = this.getViews();
            console.log(views);
            this.set_selected(views.first().value());
            views.each(function(itemView){
                itemView.on('click', function(){
                    this.open_template(itemView);
                }, listView);
                itemView.model.on('change', function(){
                    this.render();
                    this.$el.addClass('active');
                }, itemView);
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
        set_selected: function(itemView){
            if (this.selected_template){
                this.selected_template.$el.removeClass('active');
            }
            this.selected_template = itemView;
            itemView.$el.addClass('active');
        },
        open_template: function(itemView){
            this.editor.open_template(itemView.model, itemView);
            this.set_selected(itemView);
        },
    });

    var EditorNameView = Backbone.View.extend({
        el: false,
        template: '#template-editor-name-tmpl',
        serialize: function(){
            return this.model.toJSON();
        }
    });

    var EditorNameEditView = Backbone.View.extend({
        el: false,
        template: '#template-editor-name-edit-tmpl',
        serialize: function(){
            return this.model.toJSON();
        }
    });

    var EditorSourceView = Backbone.View.extend({
        el: false,
        template: '#template-editor-content-source-tmpl',
        events: {
            'change textarea': 'changed'
        },
        changed: function(){
            this.model.set('source', this.$('textarea').first().val());
        },
    });

    var EditorDataView = Backbone.View.extend({
        el: false,
        template: '#template-editor-content-data-tmpl',
        events: {
            'change textarea': 'changed'
        },
        serialize: function(){
            var data = this.model.toJSON();
            data.sample_data = JSON.stringify(data.sample_data);
            return data;
        },
        changed: function(){
            this.model.set('sample_data', JSON.parse(this.$('textarea').first().val()));
        },
    });

    var EditorPreviewView = Backbone.View.extend({
        el: false,
        template: '#template-editor-content-preview-tmpl',
    });

    var EditorView = Backbone.Layout.extend({
        el: false,
        template: '#template-editor-tmpl',
        events:{
            'click #save-button': 'save_template',
            'click #source-pill': 'show_source',
            'click #data-pill': 'show_data',
            'click #preview-pill': 'show_preview',
            'click #editor-name-link': 'edit_name',
            'change #editor-name input': 'set_name',
            'blur #editor-name input': 'show_name',
        },
        initialize: function(options){
            this.setView('#editor-name', new EditorNameView({ model: options.model }));
            this.source_view = new EditorSourceView({ model: options.model });
            this.data_view = new EditorDataView({ model: options.model });
            this.item_selected = '#source-item';
            this.setView('#editor-content', this.source_view);
            options.model.on('change', function(){
                this.$('#save-button').removeClass('btn-default');
                this.$('#save-button').addClass('btn-danger');
            }, this);
        },
        afterRender: function(){
            this.$(this.item_selected).first().addClass('active');
        },
        open_template: function(model){
            this.model = model;
            this.getView('#editor-name').model = model;
            this.getView('#editor-content').model = model;
            this.render();
        },
        save_template: function(){
            var editor = this;
            this.model.save({},{
                success: function(){
                    editor.$('#save-button').addClass('btn-default');
                    editor.$('#save-button').removeClass('btn-danger');
                }
            });
        },
        show_source: function(){
            this.$(this.item_selected).first().removeClass('active');
            this.item_selected = '#source-item';
            this.$(this.item_selected).first().addClass('active');
            this.setView('#editor-content', this.source_view);
            this.source_view.render();
        },
        show_data: function(){
            this.$(this.item_selected).first().removeClass('active');
            this.item_selected = '#sample_data-item';
            this.$(this.item_selected).first().addClass('active');
            this.setView('#editor-content', this.data_view);
            this.data_view.render();
        },
        show_preview: function(){
        },
        edit_name: function(){
            var edit_view = new EditorNameEditView({ model: this.model });
            this.setView('#editor-name', edit_view);
            edit_view.render();
            edit_view.$('input').focus();
        },
        set_name: function(){
            var edit_view = this.getView('#editor-name');
            this.model.set('name', edit_view.$('input').val());
        },
        show_name: function(){
            var show_view = new EditorNameView({ model: this.model });
            this.setView('#editor-name', show_view);
            show_view.render();
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