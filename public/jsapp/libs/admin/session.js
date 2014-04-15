define(["layoutmanager","underscore", "moment"], function(Layout, _, moment) {
    // Configure globally.
    Layout.configure({ manage: true });

    _.templateSettings = {
        interpolate: /\{\%=(.+?)\%\}/g,
        evaluate: /\{\%(.+?)\%\}/g,
        escape: /\{\%\-(.+?)\%\}/g
    };

    var Model = Backbone.Model.extend({
        urlRoot: '/rest/session',
    });

    var View = Backbone.Layout.extend({
        events: {
            'click #signinModalSubmit': 'signin'
        },
        signin: function(){
            this.model.save({
                username: this.$('input[name="username"]').val(),
                password: this.$('input[name="password"]').val()
            },{
                success: function(model, response, options){
                    $('#signinModal').modal('hide');
                },
                error: function(model, response, options){
                    console.log(model, response, options);
                },
            });
        }
    });

    return {
        Model: Model,
        View: View
    };

});