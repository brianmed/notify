package Chat;

use Mojo::Base 'Mojolicious';

use Mojo::SQLite;

sub sql {
    state $sqlite = Mojo::SQLite->new("sqlite:db/chat.db");
}

sub startup {
    my $self = shift;

    $self->plugin(AccessLog => {log => $self->home->rel_file('log/access.log'), format => '%h %l %u %t "%r" %>s %b %D "%{Referer}i" "%{User-Agent}i"'});
    
    $self->plugin("Mojolicious::Plugin::Notify", {
        websocket => "/subscribe",
        listen => {
            package => "Chat::Notify",
            sub => "listen"
        },
        channel => {
            mojo => {
                action => {
                    initialize => { 
                        package => "Chat::Notify",
                        sub => "initialize"
                    }
                },
            },
            presence => {
                action => {
                    message => { 
                        package => "Chat::Notify",
                        sub => "presence"
                    }
                },
            },
            chat => {
                action => {
                    message => { 
                        package => "Chat::Notify",
                        sub => "chat"
                    }
                },
            },
        },
    });
    
    $self->plugin("bootstrap3");
    $self->plugin(JQuery  => { jquery_1 => 1 });

    $self->helper(sql => \&sql);

    $self->sql->migrations->from_string(
      "-- 1 up
       CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            inserted DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated DATETIME DEFAULT CURRENT_TIMESTAMP
       );

       CREATE TRIGGER user_update AFTER UPDATE ON user
       BEGIN
          UPDATE user SET timeStamp = DATETIME('NOW')
          WHERE rowid = new.rowid;
       END;

       CREATE TABLE chat (
            id INTEGER PRIMARY KEY,
            username TEXT,
            message TEXT,
            inserted DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated DATETIME DEFAULT CURRENT_TIMESTAMP
       );

       CREATE TRIGGER chat_update AFTER UPDATE ON chat
       BEGIN
          UPDATE chat SET timeStamp = DATETIME('NOW')
          WHERE rowid = new.rowid;
       END;
    
       -- 1 down
       DROP TABLE user;
       DROP TABLE chat;"
    )->migrate;
    
    my $r = $self->routes;
    
    $r->get("/")->to(controller => "Index", action => "slash");
}

1;
