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
                description: 'No Description',
                source: '<doc size="a4"><page>{{some_text}}</page></doc>',
                sample_data: { "some_text": "Hello World!" },
                modified: (new Date).getTime()
            };
        },
        initialize: function() {
            this.listenTo(this, 'change', this.model_changed);
        },
        model_changed: function() {
            this.has_changed_since_last_sync = true;
        },
        parse: function(resp){
            return resp.data ? resp.data : resp;
        },
        serialize: function(){
            var data = JSON.parse(JSON.stringify(this.toJSON())); //deepcopy..
            data.created = moment.unix(data.created).format("ddd, Do MMM YYYY, h:mm:ssa");
            data.modified = moment.unix(data.modified).format("ddd, Do MMM YYYY, h:mm:ssa");
            return data;
        },
        sync: function(method, model, options) {
            options = options || {};
            var success = options.success;
            options.success = function(resp) {
              success && success(resp);
              model.has_changed_since_last_sync = false;
            };
            return Backbone.sync(method, model, options);
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
        initialize: function(){
            // this.model.on('change', function(){
                // this.$el.addClass('save'); this.$el.removeClass('saved');
            // }, this);
            this.model.on('sync', function(){
                this.$el.addClass('saved'); this.$el.removeClass('save');
            }, this);
        },
        events: {
            'click a': 'clicked',
            'click .trash': 'remove',
            'mouseover a': 'show_options',
            'mouseout a': 'hide_options',
        },
        afterRender: function(){
            if (this.model.has_changed_since_last_sync){
                this.$el.addClass('save');
            }
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
        template: "#template-liblist-tmpl",
        events: {
            'click #new-button': 'new_template',
        },
        initialize: function(options){
            if (this.editor.mode == 'edit') this.template = '#template-editorlist-tmpl';
        },
        afterRender: function(){
            var listView = this;
            var views = this.getViews('#template-list-items');
            console.log(views);
            var first_view = views.first().value();
            if (first_view) this.set_selected(views.first().value());
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
                this.insertView('#template-list-items', row);
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
        new_template: function(){
            var template = new Model();
            this.collection.add(template);
            var view = new ListItemView({ model: template });
            //this.insertView('#template-list-items', view);
            this.open_template(view);
            this.render();
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
            return this.model ? this.model.toJSON() : {};
        }
    });

    var EditorNameEditView = Backbone.View.extend({
        el: false,
        template: '#template-editor-name-edit-tmpl',
        serialize: function(){
            return this.model ? this.model.toJSON() : {};
        }
    });

    var EditorDescriptionView = Backbone.View.extend({
        el: false,
        template: '#template-editor-description-tmpl',
        serialize: function(){
            return this.model ? this.model.toJSON() : {};
        }
    });

    var EditorDescriptionEditView = Backbone.View.extend({
        el: false,
        template: '#template-editor-description-edit-tmpl',
        serialize: function(){
            return this.model ? this.model.toJSON() : {};
        }
    });

    var EditorSourceView = Backbone.View.extend({
        el: false,
        template: '#template-editor-content-source-tmpl',
        events: {
            'change textarea': 'changed'
        },
        serialize: function(){
            return this.model ? this.model.toJSON() : { source: '' };
        },
        changed: function(){
            console.log('source change textarea');
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
            try {
                this.model.set('sample_data', JSON.parse(this.$('textarea').first().val()));
            }
            catch(e){
                console.log(e);
            }
        },
    });

    var EditorView = Backbone.Layout.extend({
        el: false,
        template: '#template-library-tmpl',
        events: function(){
            var events = {
                'click #preview-button': 'open_preview',
                'click #source-pill': 'show_source',
                'click #data-pill': 'show_data',
            };
            if (this.mode == 'view'){
                events['click #import-button'] = 'import_template';
            }
            if (this.mode == 'edit'){
                events['click #save-button'] = 'save_template';
                events['click #editor-name-link'] = 'edit_name';
                events['change #editor-name input'] = 'set_name';
                events['blur #editor-name input'] = 'show_name';
                events['click #template-description-link'] = 'edit_description';
                events['change #template-description textarea'] = 'set_description';
                events['blur #template-description textarea'] = 'show_description';
                events['click #editor-private-btn'] = 'set_private';
                events['click #editor-public-btn'] = 'set_public';
            }
            return events;
        },
        // events:{
            // 'click #save-button': 'save_template',
            // 'click #preview-button': 'open_preview',
            // 'click #source-pill': 'show_source',
            // 'click #data-pill': 'show_data',
            // 'click #editor-name-link': 'edit_name',
            // 'change #editor-name input': 'set_name',
            // 'blur #editor-name input': 'show_name',
            // 'click #template-description-link': 'edit_description',
            // 'change #template-description textarea': 'set_description',
            // 'blur #template-description textarea': 'show_description',
            // 'click #editor-private-btn': 'set_private',
            // 'click #editor-public-btn': 'set_public'
        // },
        initialize: function(options){
            //if (!options.model) return;
            var model = options.model;
            if (this.mode == 'edit') this.template = '#template-editor-tmpl';
            this.setView('#editor-name', new EditorNameView({ model: model }));
            this.setView('#template-description', new EditorDescriptionView({ model: model }));
            this.source_view = new EditorSourceView({ model: model });
            this.data_view = new EditorDataView({ model: model });
            this.item_selected = '#source-item';
            this.setView('#editor-content', this.source_view);
            if (model) this.watch_model(model);
        },
        watch_model: function(model){
            model.on('change', function(){ this.update_save_button_state('save'); }, this);
            model.on('sync', function(){ this.update_save_button_state('saved'); }, this);
        },
        afterRender: function(){
            this.$(this.item_selected).first().addClass('active');
            this.model.get('public') ? this.set_public() : this.set_private();
        },
        open_template: function(model){
            this.model = model;
            this.getView('#editor-name').model = model;
            this.getView('#template-description').model = model;
            //this.getView('#editor-content').model = model;
            this.source_view.model = model;
            this.data_view.model = model;
            this.render();
            this.watch_model(model);
            this.update_save_button_state();
        },
        update_save_button_state: function(state){
            if (!state){
                state = this.model.has_changed_since_last_sync ? 'save' : 'saved';
            }
            if (state == 'save'){
                this.$('#save-button').removeClass('btn-default');
                this.$('#save-button').addClass('btn-success');
                this.$('#save-button').removeAttr('disabled');
                this.$('#save-button .saved').css('display','none');
                this.$('#save-button .save').css('display','inline-block');
            } else {
                this.$('#save-button').addClass('btn-default');
                this.$('#save-button').removeClass('btn-success');
                this.$('#save-button').attr('disabled','disabled');
                this.$('#save-button .saved').css('display','inline-block');
                this.$('#save-button .save').css('display','none');
            }
        },
        save_template: function(){
            var editor = this;
            this.model.save({},{
                success: function(){
                    editor.update_save_button_state('saved');
                }
            });
        },
        import_template: function(){
            var editor = this;
            this.model.set('id', null);
            this.model.save({},{
                success: function(model, response, options){
                    this.trigger('import', model);
                    // editor.update_save_button_state('saved');
                }
            });
        },
        open_preview: function(){
            this.$('#editorPreview input[name="template"]').val(this.model.get('source'));
            this.$('#editorPreview input[name="data"]').val(JSON.stringify(this.model.get('sample_data')));
            this.$('#editorPreview').submit();
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
        edit_description: function(){
            var edit_view = new EditorDescriptionEditView({ model: this.model });
            this.setView('#template-description', edit_view);
            edit_view.render();
            edit_view.$('textarea').focus();
        },
        set_description: function(){
            var edit_view = this.getView('#template-description');
            this.model.set('description', edit_view.$('input').val());
        },
        show_description: function(){
            var show_view = new EditorDescriptionView({ model: this.model });
            this.setView('#template-description', show_view);
            show_view.render();
        },
        set_private: function(){
            this.model.set('public', false);
            this.$('#editor-public').removeClass('active');
            this.$('#editor-private').addClass('active');
            console.log('public: '+this.model.get('public'));
        },
        set_public: function(){
            this.model.set('public', true);
            this.$('#editor-public').addClass('active');
            this.$('#editor-private').removeClass('active');
            console.log('public: '+this.model.get('public'));
        },
    });

    var EditorLayout = Backbone.Layout.extend({
        initialize: function(options){
            var editor = new EditorView({
                model: options.model,
                mode: 'edit',
            });
            this.setView('#template-editor', editor);
            this.setView('#template-list', new ListView({
                editor: editor,
                model: options.model,
                collection: options.collection
            }));
        },
    });


    var LibraryLayout = Backbone.Layout.extend({
        initialize: function(options){
            var viewer = new EditorView({
                model: options.model,
                mode: 'view',
            });
            this.setView('#template-editor', viewer);
            this.setView('#template-list', new ListView({
                editor: viewer,
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
        LibraryLayout: LibraryLayout,
        ListView: ListView,
        ListItemView: ListItemView,
    };

});