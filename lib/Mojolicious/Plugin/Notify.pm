package Mojolicious::Plugin::Notify;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Loader qw(load_class);

sub register {
    my ($self, $app, $conf) = @_;
    
    if ($conf->{websocket}) {
        my $r = $app->routes;

        $r->websocket($conf->{websocket} => \&Mojolicious::Plugin::Notify::Controller::subscribe);
    }

    if ($conf->{listen}) {
        if (my $module = $conf->{listen}{package}) {
            my $e = load_class($module);

            warn(qq{Loading "$module" failed: $e}) && return if ref $e;

            my $sub = $conf->{listen}{sub};

            $app->helper("notify.listen" => $module->can($sub));
        }
    }

    $app->helper("notify.send" => sub {
        my $c = shift;
        my $channel = shift;
        my $action = shift;
        my $json = shift;

        $c->send({json => { mojo => { channel => $channel, action => $action }, %{ $json } }});
    });
    
    $app->helper("notify.invoke" => sub {
        my $c = shift;
        my $channel = shift;
        my $action = shift;

        return undef if !$conf;
        return undef if !$conf->{channel};
        return undef if !$conf->{channel}{$channel};
        return undef if !$conf->{channel}{$channel}{action};
        return undef if !$conf->{channel}{$channel}{action}{$action};

        my $_action = $conf->{channel}{$channel}{action}{$action};

        if (my $module = $_action->{package}) {
            my $e = load_class($module);

            warn(qq{Loading "$module" failed: $e}) && return if ref $e;

            my $sub = $_action->{sub};

            $module->$sub($c, $channel, $action, @_);
        }
    });
}

package Mojolicious::Plugin::Notify::Controller;

use Mojo::Base "Mojolicious::Controller";

use Mojo::JSON qw(decode_json encode_json);

sub subscribe {
    my $c = shift;
    
    $c->inactivity_timeout(3600);

    $c->notify->listen;
    
    $c->on(json => sub {
        my ($c, $json) = @_;

        $c->app->log->debug("WS: JSON: GET: " . encode_json($json));

        $c->notify->invoke($json->{mojo}{channel}, $json->{mojo}{action}, $json);
    });
    
    $c->on(finish => sub {
        my ($c, $code, $reason) = @_;

        $c->app->log->debug("WebSocket closed with status $code");
    });
}

1;
