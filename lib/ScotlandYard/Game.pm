package ScotlandYard::Game;

use strict;
use warnings;

use List::Util qw(shuffle);
use Storable qw(dclone);

use ScotlandYard::AI;
use ScotlandYard::Map;

my @DETECTIVE_STARTS = qw(13 26 29 34 50 53 91 94 103 112 117 123 138 141 155 174);
my @MRX_STARTS = qw(35 45 51 71 78 104 106 127 132 146 166 170 172);

# required opts:
# detectives => [{
#   colour => 'red', # or anything
#   type => 'detective', # or 'police'
#   station => 104, # station number
# }, { ... }, ...]
sub new {
    my ($pkg, %opts) = @_;

    my $self = bless \%opts, $pkg;

    my @start_stations = shuffle @DETECTIVE_STARTS;

    # remove occupied stations from the set of start points
    for my $d (@{ $self->{detectives} }) {
        next if !defined $d->{station};
        @start_stations = grep { $_ != $d->{station} } @start_stations;
    }

    for my $d (@{ $self->{detectives} }) {
        $d->{tickets}{taxi} = 11;
        $d->{tickets}{bus} = 8;
        $d->{tickets}{underground} = 4;
        $d->{tickets}{ferry} = 0;

        # set start station where unspecified
        $d->{station} ||= shift @start_stations;
    }

    $self->{twox_cards} = 2;
    $self->{black_tickets} = 5;
    $self->{mrx_station} = undef;
    $self->{mrx_possible_stations} = [@MRX_STARTS];
    $self->{round} = 1;

    if ($self->{computer_is_mrx}) {
        $self->{mrx_station} = $self->random_mrx_start;
    }

    return $self;
}

sub random_mrx_start {
    return $MRX_STARTS[rand @MRX_STARTS];
}

sub clone {
    my ($self) = @_;

    return dclone($self);
}

sub is_station {
    my ($pkg, $station) = @_;
    return 0 if $station !~ /^[0-9]+$/; # no non-integer stations
    return 0 if $station < 1 || $station > 199;
    return 1;
}

sub mrx_movement {
    my ($self, $type) = @_;
    my %is_possible;
    # update mrx_possible_stations (we know he moved to an adjacent station)
    for my $a (@{ $self->{mrx_possible_stations} }) {
        for my $b (ScotlandYard::Map->adjacent_stations($a)) {
            next if $self->station_has_detective($b);
            next if $type ne 'black' && $type ne $b->{type};
            $is_possible{$b->{station}} = 1;
        }
    }
    $self->{black_tickets}-- if $type eq 'black';
    $self->{mrx_possible_stations} = [keys %is_possible];
}

# XXX: you should ensure that the movement is legal before calling this
sub detective_movement {
    my ($self, $colour, $type, $station) = @_;
    for my $d (@{ $self->{detectives} }) {
        if ($d->{colour} eq $colour) {
            $d->{tickets}{$type}-- if $d->{type} ne 'police'; # police travel for free
            $d->{station} = $station;
        }
    }
}

sub mrx_must_reveal {
    my ($self, $round) = @_;
    $round ||= $self->{round};
    return ($round =~ /^(3|8|13|18)$/) ? 1 : 0;
}

sub mrx_station {
    my ($self, $station) = @_;
    $self->{mrx_station} = $station;
    $self->{mrx_possible_stations} = [$station];
}

sub station_has_detective {
    my ($self, $station) = @_;
    for my $d (@{ $self->{detectives} }) {
        return 1 if $d->{station} == $station;
    }
    return 0;
}

sub next_round {
    my ($self) = @_;

    $self->{round}++;
}

sub detective {
    my ($self, $colour) = @_;
    for my $d (@{ $self->{detectives} }) {
        return $d if $d->{colour} eq $colour;
    }
    return undef;
}

sub play_as_mrx {
    my ($self) = @_;

    my ($move, $score) = ScotlandYard::AI->best_mrx_move($self);

    if (!defined $move) {
        print "Mr. X is surrounded. Detectives win!\n";
        exit 0;
    }

    print "Mr. X travels with a $move->{type} ticket.\n";
    $self->mrx_movement($move->{type});
    $self->{mrx_station} = $move->{station};

    print "Mr. X is now at station $self->{mrx_station}.\n" if $self->mrx_must_reveal;
}

sub play_as_detectives {
    my ($self) = @_;

    my ($move, $score) = ScotlandYard::AI->best_detectives_move($self);

    die "no move??" if !defined $move;

    for my $m (@$move) {
        my ($colour, $type, $station) = @$m;
        my $d = $self->detective($colour);
        print ucfirst($colour) . " $d->{type} moves from $d->{station} to $station via $type.\n";
        $self->detective_movement($colour, $type, $station);
    }
}

1;
