package ScotlandYard::Game;

use strict;
use warnings;

use List::Util qw(shuffle);

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
        $self->{mrx_station} = $MRX_STARTS[rand @MRX_STARTS];
    }

    return $self;
}

sub is_station {
    my ($pkg, $station) = @_;
    return 0 if $station !~ /^[0-9]+$/; # no non-integer stations
    return 0 if $station < 1 || $station > 199;
    return 1;
}

sub mrx_movement {
    my ($self, $type) = @_;
    my @possible;
    # update mrx_possible_stations (we know he moved to an adjacent station)
    for my $a (@{ $self->{mrx_possible_stations} }) {
        for my $b (ScotlandYard::Map->adjacent_stations($a)) {
            next if $self->station_has_detective($b);
            next if $type ne 'black' && $type ne $b->{type};
            push @possible, $b->{station};
        }
    }
    $self->{black_tickets}-- if $type eq 'black';
    $self->{mrx_possible_stations} = \@possible;
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

    if ($self->{computer_is_mrx}) {
        my $have_legal_moves = 0;
        for my $adj (ScotlandYard::Map->adjacent_stations($self->{mrx_station})) {
            next if $adj->{type} eq 'ferry' && $self->{black_tickets} == 0;
            $have_legal_moves++ if !$self->station_has_detective($adj->{station});
        }
        if (!$have_legal_moves) {
            # TODO: this should be usable within hypothetical games (i.e. just die instead?)
            print "Mr. X is surrounded. Detectives win!\n";
            exit 0;
        }
    }

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

    my @stations = shuffle ScotlandYard::Map->adjacent_stations($self->{mrx_station});

    # move to first station that is a legal move
    # TODO: abstract this into minimax search
    for my $s (@stations) {
        next if $s->{type} eq 'ferry' && $self->{black_tickets} <= 0;
        next if $self->station_has_detective($s->{station});

        my $type = $s->{type};
        $type = 'black' if $type eq 'ferry';
        print "Mr. X travels with a $type ticket.\n";
        $self->mrx_movement($s->{type});
        $self->{mrx_station} = $s->{station};
        last;
    }

    print "Mr. X is now at station $self->{mrx_station}.\n" if $self->mrx_must_reveal;
}

sub play_as_detectives {
    die "Computer can't play as detective (not implemented)\n";
}

1;
