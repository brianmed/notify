function Mojo(options) {
    var connect = function(url, options) {
        var ws = new WebSocket(url);

        $.extend(ws, { "_mojo": this });
		 
        ws.onopen = function() {
            var json = '{"mojo":{"channel":"mojo","action":"initialize"}}';

            ws.send(json);

            console.log("onopen: " + json);
        };
		 
        ws.onmessage = function (evt) { 
           var received = JSON.parse(evt.data);

           var mojo = received.mojo;

           if ("mojo" == mojo.channel) {
               if ("initialize" == mojo.action) {
                   $(this._mojo).trigger("initialize", received);
               }

               return;
           }

           var channels = this._mojo._channels;

           var channel = channels[mojo.channel];
           $(channel).trigger("receive", { mojo: this._mojo, channel: channel, data: received });
        };
		 
        ws.onclose = function() { 
            console.log("onclose");
        };

        this.ws = ws;

        $(this).trigger("connect");
    };

    // Notify events
    var on = function(name, cb) {
        $(this).bind(name, cb);
    };

    // Channel setup
    function Channel(mojo, name) {
        // Channel events
        var on = function(name, cb) {
            $(this).bind(name, cb);
        };

        var send = function(data) {
            var mojo = this._mojo;
            var ws = mojo.ws;

            ws.send(JSON.stringify({ mojo: { channel: this.name, action: "message" }, data: data }));
        }

        var defaults = {
            _mojo: mojo,
            name: name,
            on: on,
            send: send
        };

        $.extend(this, defaults);
    }

    // Allows for mojo.channel("example").on(...)
    // Allows for mojo.channel("example").send(...)
    var channel = function (name) {
        if (this._channels[name]) {
            return this._channels[name];
        }

        this._channels[name] = new Channel(this, name);

        return this._channels[name];
    }

    var defaults = {
        connect: connect,
        on: on,
        channel: channel,
        ws: null,
        _channels: {}
    };

    $.extend(this, defaults);
}
