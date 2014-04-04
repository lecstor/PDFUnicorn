define(["layoutmanager","underscore", "moment"], function(Layout, _, moment) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\%=(.+?)\%\}/g,
        evaluate: /\{\%(.+?)\%\}/g,
        escape: /\{\%\-(.+?)\%\}/g
    };

    var Model = Backbone.Model.extend({
        defaults: {
            name: 'Unnamed Template'
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
            //listView.on('click', function(template){
            //    this.$('textarea').first().val(template.source);
            //}, this);
            this.insertView('.template-list-items', listView);
        },
        afterRender: function(){
            var editor = this;
            this.getView('.template-list-items').getViews().each(function(itemView){
                itemView.on('click', function(){
                    editor.getView('.template-list-items').getViews().each(function(itemView){
                        itemView.$el.removeClass('active');
                    });
                    itemView.$el.addClass('active');
                    editor.$('textarea').first().val(this.model.get('source'));
                }, itemView);
            });
        },
        fetch_templates: function(options){
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