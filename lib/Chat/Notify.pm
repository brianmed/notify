package Chat::Notify;

use Mojo::Base '-strict';

use Mojo::JSON qw(encode_json decode_json);

sub initialize {
    my ($self, $c, $channel, $action, $json) = @_;

    $c->notify->send("mojo", "initialize", { text => "Hello Initialize" });
}

sub presence {
    my ($self, $c, $channel, $action, $json) = @_;

    $c->app->log->debug("Notify: $channel: " . encode_json($json));

    eval {
        $c->sql->db->query('insert into user (username) values (?)', $json->{data}{username});
    };

    my $exist = $c->sql->db->query('select username from user where username = ?', $json->{data}{username})->hash;
    if ($exist) {
        $c->notify->send($channel, "message", { login => "success" });
    }
    else {
        $c->notify->send($channel, "message", { login => "failure" });
    }
}

sub chat {
    my ($self, $c, $channel, $action, $json) = @_;

    $c->app->log->debug("Notify: chat: " . encode_json($json));

    if ("refresh" eq $json->{data}{action}) {
        my $messages = $c->sql->db->query('select * from chat order by id desc limit 10')->hashes->reverse->to_array;

        # $c->app->log->debug("Notify: $channel: messages: " . $c->dumper($messages));

        $c->notify->send($channel, "message", { action => "refresh", messages => $messages });
    }
    elsif ("incoming" eq $json->{data}{action}) {
        my $id = $c->sql->db->query('insert into chat (username, message) values (?, ?)', $json->{data}{username}, $json->{data}{message})->last_insert_id;

        my $message = $c->sql->db->query('select * from chat where id = ?', $id)->hash;

        my $payload = { action => "outgoing", inserted => $message->{inserted}, message => $json->{data}{message}, username => $json->{data}{username} };
        $c->notify->send($channel, "message", $payload);

        $c->sql->pubsub->notify(chat => encode_json({ %{ $payload } , channel => $channel }));
    }
}

sub listen {
    my ($c) = @_;

    $c->sql->pubsub->listen(chat => sub {
        my ($pubsub, $payload) = @_;

        my $hash = decode_json($payload);
        $hash->{broadcast} = 1;
        
        $c->notify->send($hash->{channel}, "message", $hash);
    });
}

1;
