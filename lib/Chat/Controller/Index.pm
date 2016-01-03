package Chat::Controller::Index;

use Mojo::Base 'Mojolicious::Controller';

sub slash {
    my $self = shift;
    
    $self->render;
}

1;
