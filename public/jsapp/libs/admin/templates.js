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

    var EditorView = Backbone.Layout.extend({
        template: "#template-editor-tmpl",
    });

    var ListItemView = Backbone.Layout.extend({
        template: "#template-list-item-tmpl",
    });

    var ListView = Backbone.Layout.extend({
        template: "#template-list-tmpl",
        beforeRender: function(){
            var view = this;
            this.collection.each(function(template){
                var row = new ListItemView({ model: template });
                this.insertView('.template-list-items', row);
            }, this);
        },
    });


    return {
        Model: Model,
        Collection: Collection,
        EditorView: EditorView,
        ListView: ListView,
        ListItemView: ListItemView,
    };

});