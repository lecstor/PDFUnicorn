/**
 * @author Jason Galea
 */

define(["layoutmanager","underscore"], function(Layout, _) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\{(.+?)\}\}/g
    };

    var ItemListView = Backbone.Layout.extend({
        initialize: function(args){
            this.add_button = args.add_button_view;
            this.add_button.on('click', this.add_row, this);
        },
        add_row: function(){
            console.log('add row!!');
            var view = new ItemView({ model: { item_number: this.$el.size().toString() } });
            view.render();
            console.log(view.el);
            this.$el.append(view.$el);
            console.log(this.el);
        }
    });

    var ItemView = Backbone.Layout.extend({
        template: "#item-row-tmpl",
        className: 'row list-item',
        serialize: function() {
            console.log('serialize!!');
            console.log(this.model);
            return this.model;
        }
    });

    var AddButtonView = Backbone.Layout.extend({
        events: {
            'click': 'click'
        },
        click: function(e){
            console.log('clicked!!')
            e.preventDefault();
            this.trigger('click');
        }
    });

    var add_button_view = new AddButtonView();
    add_button_view.setElement('#add_item_button');
    console.log(add_button_view.el);

    var item_list_view = new ItemListView({ add_button_view: add_button_view });
    item_list_view.setElement('#invoice-item-list');

    return {
        add_button: add_button_view,
        item_list: item_list_view,
    };

});
